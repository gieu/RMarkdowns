# RMarkdowns

Repositorio de cuadernos y tutoriales educativos en R Markdown del [Grupo de Informática Educativa](https://github.com/gieu/RMarkdowns). Aquí se conservan los archivos fuente `.Rmd`, sus versiones renderizadas `.html` y los datos necesarios para ejecutarlos.

Esta guía explica cómo agregar un cuaderno, actualizar uno existente y preparar sus dependencias tanto en el computador de quien lo desarrolla como en el servidor.

> **Importante:** los cuadernos actuales usan `output: learnr::tutorial` y `runtime: shiny_prerendered`. Son aplicaciones interactivas que necesitan R y Shiny en el servidor. Subir únicamente el HTML a un alojamiento estático, como GitHub Pages, no permite ejecutar sus ejercicios de R.

## 1. Cómo está organizado el repositorio

```text
RMarkdowns/
├── datos/                      # Datos compartidos: CSV, Excel e imágenes
├── deploy/                     # Imagen, dependencias y preparación del servidor
├── markdowns/
│   ├── clase_doctorado/
│   │   ├── Education_Stats_Interactive_Tutorial_Corrected.Rmd
│   │   └── Education_Stats_Interactive_Tutorial_Corrected.html
│   └── tutorial_tecnicas_de_conteo/
│       ├── V2_Tutorial_Tecnicas_de_Conteo.Rmd
│       ├── V2_Tutorial_Tecnicas_de_Conteo.html
│       └── images/
├── index.html                  # Portada compilada con React
├── static/                     # JavaScript, CSS y recursos de la portada
└── asset-manifest.json          # Referencias a los archivos de la portada
```

- Usa una carpeta por cuaderno dentro de `markdowns/`. Para los nuevos nombres, prefiere letras sin tildes, números y guiones o guiones bajos.
- Conserva el mismo nombre base para el `.Rmd` y el `.html`.
- Incluye las imágenes, licencias, scripts y demás archivos que el cuaderno necesite. Algunos existentes incluyen un `license.html`.
- No renombres carpetas ya publicadas sin coordinar la actualización de sus enlaces.

El sitio se publica bajo `/shiny/` del dominio `grupoinformaticaeducativa.uninorte.edu.co`, mediante el contenedor Docker `shiny_server`. Un webhook recibe los cambios de `master`.

Los auxiliares de `deploy/` preparan una imagen y un sitio separados antes de reemplazar el servicio. **Incluirlos en Git no instala automáticamente el nuevo webhook**: hay que revisar y cambiar su configuración en el servidor. El `docker-compose.yml` principal y los tres scripts `install_*.sh` siguen estando fuera de este repositorio, en `/home/ubuntu/docker-compose/shiny/`. No hay un `renv.lock`.

## 2. Preparar el entorno de trabajo

Necesitas:

- Git y acceso de escritura al repositorio, o permiso para proponer cambios.
- R y, preferiblemente, RStudio.
- Pandoc, incluido en RStudio. Si trabajas desde una terminal, verifica que `rmarkdown` pueda encontrarlo.
- Acceso a los repositorios de paquetes durante la instalación.

Si aún no tienes una copia local:

```bash
git clone https://github.com/gieu/RMarkdowns.git
cd RMarkdowns
```

Si ya la tienes, abre una terminal en su raíz. Antes de cambiar de rama, revisa `git status` y guarda tus cambios pendientes. Luego:

```bash
git switch master
git pull --ff-only origin master
git switch -c agregar-mi-cuaderno
```

Los comandos siguientes suponen que estás en la raíz del repositorio. Cambia `mi_cuaderno` por el nombre real.

## 3. Crear el cuaderno y agregar sus archivos

Crea la carpeta `markdowns/mi_cuaderno/` y guarda allí `mi_cuaderno.Rmd`. Esta es una plantilla mínima de tutorial interactivo:

````markdown
---
title: "Mi nuevo cuaderno"
output: learnr::tutorial
runtime: shiny_prerendered
---

```{r setup, include=FALSE}
library(learnr)
library(ggplot2)
```

## Introducción

Describe los objetivos y los datos del tutorial.

## Ejercicio

Modifica el gráfico y ejecuta el código.

```{r grafico, exercise=TRUE}
ggplot(mtcars, aes(x = wt, y = mpg)) +
  geom_point()
```
````

El bloque `setup` debe cargar los paquetes y preparar los objetos que necesitan los ejercicios. No dependas de variables que creaste manualmente en la consola de RStudio.

### Datos, imágenes y rutas

- Guarda los datos compartidos en `datos/` y las imágenes propias en la carpeta del cuaderno, por ejemplo `markdowns/mi_cuaderno/images/`.
- Usa rutas relativas al `.Rmd`. Por ejemplo, desde `markdowns/mi_cuaderno/`:

  ```r
  desempenio <- read.csv("../../datos/desempenio.csv", sep = ";", header = TRUE)
  ```

- Una imagen local se puede incluir como `![Descripción](images/figura.png)`.
- No uses rutas personales como `/Users/alguien/...` o `C:/Users/...`, ni un `setwd()` que dependa de tu computador.
- Respeta mayúsculas y minúsculas: una ruta que funciona en tu equipo puede fallar en Linux.
- Si copias otro cuaderno, revisa todas sus referencias, incluido `license.html`; no basta con copiar el `.Rmd`.
- Evita depender de URLs externas cuando puedas distribuir legalmente el recurso en el repositorio. Verifica siempre los enlaces que conserves.
- Publica únicamente datos autorizados y anonimizados. No incluyas credenciales ni información personal.

## 4. Declarar e instalar dependencias

**Instalar un paquete en tu computador no lo instala en el servidor.** Para un tutorial `learnr`, los paquetes deben estar disponibles tanto al renderizar como al ejecutar los ejercicios en línea.

### 4.1. Registrar lo que necesita cada cuaderno

Para cada cuaderno nuevo, agrega estos dos archivos en su carpeta:

| Archivo | Contenido |
| --- | --- |
| `install-deps.R` | Lista explícita e instalación de los paquetes necesarios. |
| `DEPENDENCIAS.md` | Versión de R y paquetes probados, requisitos del sistema e instrucciones especiales. |

Estos archivos son una convención propuesta para los próximos cuadernos; los actuales todavía no los incluyen. **Para el servidor, la lista central que debes actualizar es `deploy/install-deps.R`.** El instalador local de cada cuaderno no se ejecuta automáticamente durante el despliegue.

Revisa **todo** el `.Rmd`, no solo `setup`: también cuentan los paquetes utilizados en ejercicios, soluciones, scripts importados y llamadas como `paquete::funcion()`.

Por ejemplo, el tutorial de conteo utiliza `DiagrammeR`, `gtools`, `combinat` y `learnr`; el de doctorado utiliza, entre otros, `tidyverse`, `readxl`, `ggpubr` y `car`. No es necesario instalar todos los paquetes de todos los cuadernos para agregar uno nuevo.

### 4.2. Crear un instalador explícito

Para la plantilla anterior, guarda lo siguiente en `markdowns/mi_cuaderno/install-deps.R`:

```r
paquetes <- c("rmarkdown", "knitr", "learnr", "shiny", "ggplot2")

faltantes <- paquetes[!vapply(
  paquetes,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]

if (length(faltantes) > 0) {
  install.packages(faltantes, repos = "https://cloud.r-project.org")
}

no_disponibles <- paquetes[!vapply(
  paquetes,
  requireNamespace,
  logical(1),
  quietly = TRUE
)]

if (length(no_disponibles) > 0) {
  stop("No se pudieron cargar: ", paste(no_disponibles, collapse = ", "))
}
```

Ejecuta desde la raíz:

```bash
Rscript --vanilla markdowns/mi_cuaderno/install-deps.R
```

Cuando agregues una dependencia:

1. Agrégala a `paquetes` y cárgala en el cuaderno con `library()` o úsala mediante `paquete::funcion()`.
   Agrégala también al listado central de `deploy/install-deps.R`.
2. Ejecuta el instalador y prueba el cuaderno completo en una sesión nueva.
3. Registra la versión probada y cualquier requisito adicional en `DEPENDENCIAS.md`.
4. Incluye esos cambios junto con el `.Rmd` y el `.html` actualizado.
5. Repite la instalación y la comprobación con el usuario de R del servidor antes de habilitar el cuaderno.

No pongas `install.packages()` en bloques que se ejecuten al abrir el tutorial o al resolver ejercicios. La instalación es una tarea de preparación, no de cada visita.

El ejemplo anterior usa CRAN actual para el entorno local. **No lo uses para actualizar indiscriminadamente el servidor antiguo.** La imagen del servidor conserva R `4.1.2` y el repositorio fechado `2022-03-09`. Si una dependencia no existe en ese repositorio o necesita una versión más reciente de R, hay que revisar y probar el cambio de entorno por separado.

Ese repositorio entrega paquetes **precompilados** solo si la petición declara el sistema operativo mediante `HTTPUserAgent`. La imagen lo hace en el perfil de R, pero `Rscript --vanilla` lo omite, y entonces se descarga código fuente: la instalación se vuelve lenta y falla en paquetes que necesitan compiladores o `cmake`, como `nloptr`, que arrastra `rstatix`, `ggpubr` y `car`. Por eso `deploy/install-deps.R` fija esa opción por sí mismo. Si agregas un instalador propio que use `--vanilla`, haz lo mismo. Si aparece un error de compilación al instalar un paquete, comprueba primero que se esté descargando el binario.

### 4.3. Versiones y dependencias especiales

En la consola de R puedes consultar:

```r
R.version.string
packageVersion("learnr")
packageVersion("ggplot2")
rmarkdown::pandoc_version()
sessionInfo()
```

Registra los valores reales probados. El instalador de ejemplo **solo instala lo que falta**: no actualiza versiones existentes ni garantiza versiones idénticas entre equipos. Si hace falta una versión mínima o específica, documenta cómo instalarla y comprueba que funciona con la versión de R del servidor.

- Los paquetes de **Bioconductor** o **GitHub** requieren instrucciones adicionales en el instalador. Documenta su origen y la versión o revisión exacta; no dependas de una rama que cambie sin control.
- Algunos paquetes requieren bibliotecas del sistema, compiladores o herramientas externas. Registra sus nombres e instrucciones para el sistema operativo del servidor y coordina su instalación con quien lo administra.
- No actualices toda la biblioteca compartida de R para resolver una sola dependencia. Una actualización puede romper otros tutoriales.
- Si se necesita fijar el entorno completo, se puede acordar el uso de `renv`. Actualmente no está configurado: no asumas que `renv::restore()` reconstruirá este repositorio. Su adopción debe incluir el archivo de bloqueo, las instrucciones de restauración y la integración con el servidor.

## 5. Renderizar y probar localmente

Primero instala las dependencias. Después comprueba Pandoc:

```bash
Rscript --vanilla -e 'stopifnot(rmarkdown::pandoc_available()); print(rmarkdown::pandoc_version())'
```

Genera el HTML en una sesión limpia de R:

```bash
Rscript --vanilla -e 'rmarkdown::render("markdowns/mi_cuaderno/mi_cuaderno.Rmd")'
```

Después inicia el tutorial:

```bash
Rscript --vanilla -e 'rmarkdown::run(file = "mi_cuaderno.Rmd", dir = "markdowns/mi_cuaderno")'
```

Abre la dirección local que aparezca en la consola. Detén la aplicación con `Ctrl+C` al terminar. En RStudio también puedes abrir el `.Rmd` y usar **Run Document**.

Comprueba que:

- El tutorial abre sin errores y muestra todos sus apartados.
- Cada ejercicio ejecuta R y sus soluciones y comprobaciones funcionan.
- Los datos, imágenes, gráficos y enlaces se cargan correctamente.
- No necesitas ejecutar manualmente bloques previos en la consola.
- Las carpetas de recursos generadas, si las hay, acompañan al HTML. No asumas que todos los recursos están incrustados.

**Renderizar sin errores no prueba la ejecución de todos los ejercicios.** Hay código de Shiny que se ejecuta al abrir la aplicación o al pulsar un botón.

### El HTML debe corresponder al entorno que lo ejecuta

Un HTML de `learnr` no contiene solamente texto: también conserva código y referencias a recursos del paquete. Durante la depuración, un HTML generado con `learnr 0.11.6` falló en el servidor con `learnr 0.10.1`, con el mensaje `Couldn't normalize path in addResourcePath` para `i18n-21.6.10`.

No se arregla instalando un paquete llamado `i18n-21.6.10`, ni subiendo únicamente ese HTML. Hay que **regenerarlo desde el `.Rmd` dentro de la imagen que va a servirlo**. `deploy/render-notebooks.R` hace esto para todos los cuadernos, cada uno en una sesión nueva, sin sobrescribir el repositorio fuente.

Si lo que necesitas es un documento **estático**, usa `output: html_document` y elimina `runtime: shiny_prerendered`. Adapta también los ejercicios y funciones de `learnr`: cambiar solo el encabezado no convierte un tutorial interactivo en uno estático.

## 6. Guardar y enviar la actualización

Revisa los cambios y agrega únicamente los archivos del cuaderno:

```bash
git status --short
git diff --check
git diff
git add markdowns/mi_cuaderno/
```

Si agregaste datos compartidos, añade sus rutas específicas con `git add`. Revisa que no estés incluyendo `.Rhistory`, `.RData`, cachés, archivos temporales o bibliotecas locales de paquetes. El `.gitignore` actual no cubre todos esos casos.

Antes de confirmar:

```bash
git diff --cached --check
git diff --cached
git commit -m "Agregar tutorial mi_cuaderno"
git push -u origin agregar-mi-cuaderno
```

Abre una solicitud de cambios hacia `master`, explica las nuevas dependencias y espera la revisión. Sigue el proceso acordado por el equipo para integrar y desplegar los cambios.

Para **actualizar un cuaderno existente**, conserva su carpeta y nombre de archivo, modifica el `.Rmd`, actualiza sus dependencias si corresponde, vuelve a generar el `.html` y repite las pruebas y el envío. Si modificas datos compartidos o paquetes del servidor, prueba también los otros cuadernos afectados.

## 7. Actualizar el servidor

### Configuración confirmada

| Elemento | Configuración |
| --- | --- |
| Carpeta del servicio | `/home/ubuntu/docker-compose/shiny` |
| Repositorio fuente | `mountpoints/apps/` |
| Ruta dentro del contenedor | `/srv/shiny-server` |
| Usuario que ejecuta los cuadernos | `shiny`, definido por `run_as shiny;` |
| Registros | `/var/log/shiny-server`, en el volumen Docker `shiny_logs` |
| R / learnr | `4.1.2` / `0.10.1` |
| Repositorio de paquetes | `https://packagemanager.rstudio.com/cran/__linux__/focal/2022-03-09` |
| Shiny Server / Pandoc de la imagen propuesta | `1.5.18.979` / `3.14` |

El contenedor arranca como `root`, pero Shiny ejecuta los cuadernos como `shiny`. La carpeta local `logs/` no está montada en el Compose compartido.

| Archivo | Función |
| --- | --- |
| `deploy/Dockerfile` | Fija R, Shiny Server y Pandoc. Usa los tres instaladores existentes del servidor como contexto de construcción. |
| `deploy/install-deps.R` | Instala lo que falta del repositorio fechado y hace fallar la construcción si algún paquete no carga. `--check` solo comprueba. |
| `deploy/render-notebooks.R` | Copia el sitio a una salida nueva, renderiza todos los `.Rmd` y guarda registros fuera de la carpeta publicable. |
| `deploy/prepare-release.sh` | Construye una imagen, comprueba paquetes como `shiny` y prepara el sitio sin activar Compose. |
| `deploy/webhook.sh` | Obtiene `origin/master` con `fetch` y `archive`, sin modificar el checkout servido. Por defecto solo prepara. |

Los instaladores del sistema pueden requerir acceso a Internet. Algunos cuadernos todavía leen URLs externas durante el renderizado, incluidas URLs del propio sitio: prepara la nueva versión **mientras la anterior sigue funcionando**. Es preferible usar rutas relativas para los datos incluidos en el repositorio.

### Preparación manual, sin desplegar

`mountpoints/apps/` es el checkout que sirve el sitio y **no se actualiza** con `git pull`, así que `deploy/` no está ahí hasta después de un despliegue. Ejecuta en el servidor, extrayendo una copia del commit ya integrado en `origin/master` (sin modificar el checkout):

```bash
cd /home/ubuntu/docker-compose/shiny
mkdir -p releases
git -C mountpoints/apps fetch origin master
STAMP=$(date +%Y%m%d-%H%M%S)
SOURCE=$(mktemp -d "$PWD/releases/source-$STAMP-XXXXXX")
git -C mountpoints/apps archive FETCH_HEAD | tar -x -C "$SOURCE"
RELEASE="$PWD/releases/manual-$STAMP"
IMAGE="shiny-server:manual-$STAMP"

bash "$SOURCE/deploy/prepare-release.sh" "$PWD" "$SOURCE" "$RELEASE" "$IMAGE"
```

La salida debe terminar con `PREPARACIÓN COMPLETA` y todos los cuadernos deben renderizar correctamente. El resultado queda en:

```text
releases/manual-.../
├── context/                    # Copia de los archivos usados para construir
├── prepared/
│   ├── site/                   # Única carpeta que debe publicarse
│   ├── logs/                   # Un registro por cuaderno
│   ├── resultados.tsv          # Estado de cada renderizado; 0 significa éxito
│   └── entorno.txt
└── compose.release.json        # Override que selecciona la imagen y el sitio
```

Si falla un paquete o un renderizado, el script devuelve un estado distinto de cero y no activa el servicio. No reutilices una carpeta de salida existente: crea otra para conservar los registros anteriores.

Para comprobar la imagen preparada sin sustituir producción:

```bash
sudo docker run -d \
  --name shiny_release_review \
  --user root \
  --publish 127.0.0.1:3840:3838 \
  --mount "type=bind,source=$RELEASE/prepared/site,target=/srv/shiny-server" \
  "$IMAGE"
```

Desde **tu computador**, abre un túnel con tu dirección y autenticación SSH habituales:

```bash
ssh -N -L 127.0.0.1:3840:127.0.0.1:3840 usuario@servidor
```

Visita `http://127.0.0.1:3840/markdowns/` y comprueba los cuadernos y ejercicios. No abras ese puerto en el firewall público. Si recibes `Permission denied (publickey)`, resuelve primero la autenticación SSH; si recibes `ERR_CONNECTION_REFUSED`, comprueba el túnel y el contenedor de prueba antes de cambiar paquetes.

### Sustituir el webhook, solo después de revisar y aprobar

El webhook anterior detenía y eliminaba el contenedor antes de construir. No lo uses para las pruebas y no ejecutes ambos procedimientos a la vez.

El nuevo flujo obtiene una copia del commit de `origin/master`, construye una imagen con una etiqueta propia, regenera los HTML y recién entonces puede activar **únicamente** `shiny_server`. No hace `git pull` sobre los archivos publicados, no instala paquetes al recibir una visita y no ejecuta `docker system prune`.

`webhook.sh` no vive en la carpeta publicada: se toma siempre de `origin/master`. Se instala reemplazando solo `/home/ubuntu/utils/hooks/apps/update_shiny.sh` (el `hooks.json` no cambia y el servicio `webhook` no necesita reiniciarse). Antes guarda una copia del original:

```bash
cp /home/ubuntu/utils/hooks/apps/update_shiny.sh \
   /home/ubuntu/utils/hooks/apps/update_shiny.sh.bak-$(date +%Y%m%d)
```

El nuevo `update_shiny.sh` es un envoltorio que descarga la última versión de `webhook.sh` y la ejecuta **solo en modo `--prepare-only`**:

```bash
#!/bin/bash
set -Eeuo pipefail
exec >> /home/ubuntu/docker-compose/shiny/webhook.log 2>&1
echo "=== $(date -Is) ==="
cd /home/ubuntu/docker-compose/shiny/mountpoints/apps
git fetch origin master
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
git show FETCH_HEAD:deploy/webhook.sh > "$tmp"
bash "$tmp" --prepare-only
```

Mientras `deploy/` no esté en `master`, el envoltorio falla sin consecuencias y registra el error. Cada push a `master` construye y renderiza en una carpeta aparte, y **no modifica producción**. Sigue el avance con `tail -f /home/ubuntu/docker-compose/shiny/webhook.log`. Para volver al comportamiento anterior, restaura la copia de seguridad.

Requiere Git, `flock`, Python 3, Docker y Docker Compose v1 con permisos no interactivos. `SHINY_SERVER_DIR` permite cambiar la carpeta del servicio. Usa el código **ya integrado en `origin/master`**, no los cambios locales sin commit.

La activación es siempre manual, después de revisar la preparación:

```bash
cd /home/ubuntu/docker-compose/shiny/mountpoints/apps
git fetch origin master
git show FETCH_HEAD:deploy/webhook.sh > /tmp/webhook.sh
bash /tmp/webhook.sh --deploy
```

Después del primer `--deploy`, el contenedor sirve la carpeta `releases/release-…` y no el checkout. Si alguien ejecuta `docker-compose up` a mano sin el archivo `compose.release.json`, volvería al montaje anterior. Además, el checkout `mountpoints/apps/` deja de actualizarse.

El `up` utiliza `--no-build --no-deps --force-recreate -d shiny_server`. El override cambia la imagen y el montaje de aplicaciones; conserva los volúmenes de registros y datos compartidos del Compose principal. La sustitución puede interrumpir sesiones: no es un despliegue sin tiempo de inactividad.

Antes de activar se guarda `compose.previous.json` y se etiqueta la imagen anterior. Si Compose falla al activar, se intenta restaurar esa configuración. Si el fallo se descubre al probar la web, puedes restaurarla manualmente:

```bash
sudo docker-compose \
  -f /home/ubuntu/docker-compose/shiny/docker-compose.yml \
  -f /ruta/de/la/release/compose.previous.json \
  up --no-build --no-deps --force-recreate -d shiny_server
```

Conserva la imagen y la carpeta del sitio anterior hasta terminar las pruebas. La reversión restaura imagen y montaje, no deshace modificaciones de datos en un volumen compartido. No edites las carpetas de releases activadas. Los cambios a `deploy/webhook.sh` se aplican al integrarse en `master`, porque el envoltorio lo descarga cada vez. Solo los cambios al envoltorio `update_shiny.sh` requieren actualizarlo a mano en el servidor.

### Diagnóstico después de publicar

El enlace de un tutorial interactivo tiene esta estructura:

```text
https://grupoinformaticaeducativa.uninorte.edu.co/shiny/markdowns/mi_cuaderno/
```

El índice `/shiny/markdowns/` lista los cuadernos disponibles. La portada React puede mostrar menos tarjetas porque mantiene una lista independiente. Un HTML estático se enlaza al archivo `.html`; eso no sustituye la URL de ejecución de Shiny.

Abre el cuaderno que falla y consulta inmediatamente sus registros:

```bash
sudo docker exec shiny_server \
  find /var/log/shiny-server \
  -maxdepth 1 -type f -name '*.log' -mmin -10 \
  -print -exec tail -n 80 {} \;
sudo docker logs --since 10m --tail 100 shiny_server
```

Shiny puede borrar el archivo de registro al terminar el proceso; en esa instalación su contenido también aparece en `docker logs`. No interpretes el mensaje genérico del navegador como prueba de un paquete faltante: busca el error concreto y oculta datos personales antes de compartir registros.

### El paquete está instalado, pero Shiny no lo encuentra

Lo más frecuente es que se haya instalado en la biblioteca personal de otro usuario, o con otra instalación de R. **Con el mismo usuario, ejecutable y entorno del servicio**, comprueba:

```r
R.version.string
.libPaths()
stopifnot(requireNamespace("learnr", quietly = TRUE))
packageVersion("learnr")
```

Repite la comprobación para cada paquete nuevo. Ejecutar `install.packages()` como administrador no garantiza que el servicio pueda encontrar el paquete. El administrador debe configurar una biblioteca accesible y sus permisos; no lo resuelvas dando permisos de escritura generales.

### Pruebas de los auxiliares

Con Python 3, R, `rmarkdown` y Pandoc disponibles:

```bash
python3 -B -m unittest discover -s deploy/tests -v
```

Las pruebas locales comprueban sesiones limpias, rutas con espacios y `&`, conservación de los originales, fallo por licencia ausente y protección frente a despliegues accidentales. Docker, Git remoto y Compose se simulan en las pruebas de fallos; no sustituyen la construcción y las pruebas reales de una imagen.

## 8. Agregar el acceso en la portada

Publicar el cuaderno y mostrarlo en la portada son tareas distintas. La lista de tutoriales está compilada en `static/js/main.d6ddcc48.chunk.js`; no se genera recorriendo las carpetas de `markdowns/`.

El mapa de fuentes `static/js/main.d6ddcc48.chunk.js.map` conserva una referencia al archivo original `data.js`, con entradas de este tipo:

```javascript
{
  url: "markdowns/mi_cuaderno/",
  name: "Mi nuevo cuaderno"
}
```

Para agregar una tarjeta, hay que localizar el proyecto fuente de la portada, incorporar la entrada y volver a compilarlo manteniendo la ruta base `/shiny/`. Este repositorio contiene el resultado compilado, pero no el proyecto completo ni su `package.json`, por lo que **no se puede asumir que `npm install` y `npm run build` funcionen aquí**.

No edites a mano el JavaScript minificado ni cambies los nombres con hash. Al publicar una nueva compilación, actualiza de forma coherente `index.html`, `asset-manifest.json` y los recursos generados de `static/`. Si no tienes las fuentes, coordina este cambio con el responsable de la portada y comparte mientras tanto el enlace directo verificado del cuaderno.

## Lista de verificación

- [ ] `.Rmd` y `.html` actualizados dentro de la misma carpeta.
- [ ] Datos, imágenes, licencias y recursos adicionales incluidos.
- [ ] Dependencias declaradas y versiones probadas documentadas.
- [ ] Renderizado en una sesión limpia y ejercicios probados localmente.
- [ ] Cambios revisados e integrados en la rama que se despliega.
- [ ] Paquetes y requisitos del sistema disponibles para el usuario de Shiny.
- [ ] Actualización del servidor y URL pública verificadas.
- [ ] Enlace de la portada actualizado, si corresponde.
