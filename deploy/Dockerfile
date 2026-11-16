FROM rocker/r-ver:4.1.2

ENV S6_VERSION=v2.1.0.2 \
    SHINY_SERVER_VERSION=1.5.18.979 \
    PANDOC_VERSION=3.14

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    libxml2-dev libcurl4-openssl-dev libssl-dev libfontconfig1-dev \
    libharfbuzz-dev libfribidi-dev libfreetype6-dev libpng-dev \
    libtiff5-dev libjpeg-dev && \
    rm -rf /var/lib/apt/lists/*

# The build context supplies the three existing server installation scripts.
COPY install_shiny_server.sh /usr/bin/install_shiny_server.sh
COPY install_pandoc.sh /usr/bin/install_pandoc.sh
COPY install_s6init.sh /usr/bin/install_s6init.sh
RUN install_shiny_server.sh

COPY deploy/install-deps.R deploy/render-notebooks.R /opt/notebooks/
RUN Rscript --vanilla /opt/notebooks/install-deps.R

RUN mkdir -p /srv/shiny-server/datos

EXPOSE 3838
CMD ["/init"]
