# syntax=docker/dockerfile:1
# ÖlçekLab R analiz motoru. Yerel ve Hugging Face Space için bağlantı noktası 8000;
# bağlantı noktası PORT ortam değişkeninden okunur.
FROM rocker/r-ver:4.4.3

# Türkçe metinler için UTF-8 yerel ayarı zorunlu (engine/R/00_locale.R).
ENV LANG=C.UTF-8 LC_ALL=C.UTF-8

# Sistem kitaplıkları: officer/flextable (xml2, systemfonts, gdtools), httpuv, nanonext, httr2
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      libxml2-dev libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
      libpng-dev libjpeg-dev libtiff-dev libcairo2-dev libcurl4-openssl-dev libssl-dev \
      zlib1g-dev libsodium-dev cmake \
 && rm -rf /var/lib/apt/lists/*

# Paketler renv.lock'taki sürümlerle, tarihli Posit Package Manager anlık görüntüsünden kurulur.
ARG PPM_DATE=2026-10-31
ENV RENV_CONFIG_PAK_ENABLED=FALSE
WORKDIR /app
COPY renv.lock ./renv.lock
RUN CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")" \
 && REPO="https://packagemanager.posit.co/cran/__linux__/${CODENAME}/${PPM_DATE}" \
 && Rscript -e "install.packages('renv', repos = '${REPO}')" \
 && Rscript -e "options(renv.config.repos.override = '${REPO}'); renv::restore(lockfile = 'renv.lock', library = .libPaths()[1], prompt = FALSE)" \
 && Rscript -e "stopifnot(as.character(packageVersion('lavaan')) == '0.7.2')"

COPY plumber.R run.R healthcheck.R ./
COPY R ./R
COPY tests ./tests

# Hugging Face Spaces 1000 numaralı kullanıcıyı bekler.
RUN useradd -m -u 1000 olceklab \
 && mkdir -p /app/test-results \
 && chown olceklab:olceklab /app/test-results
USER olceklab

ENV PORT=8000 HOST=0.0.0.0 OLCEKLAB_ENGINE_DIR=/app
EXPOSE 8000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 CMD ["Rscript", "/app/healthcheck.R"]
CMD ["Rscript", "/app/run.R"]
