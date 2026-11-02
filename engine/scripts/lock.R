# renv.lock'u, testlerin koştuğu R kütüphanesinden yeniden üretir.
# Kullanım (engine/ içinde): Rscript scripts/lock.R
# Depo adresi: Posit Package Manager'ın tarihli anlık görüntüsü (sürüm sabit).
ppm_date <- Sys.getenv("OLCEKLAB_PPM_DATE", "2026-10-31")
options(repos = c(CRAN = sprintf("https://packagemanager.posit.co/cran/%s", ppm_date)))
pkgs <- c(
  # analiz
  "lavaan", "semTools", "psych", "GPArotation", "MASS", "mvtnorm", "pbivnorm",
  # API, işler, rapor, veri
  "plumber", "mirai", "nanonext", "officer", "flextable", "jsonlite", "readxl", "digest",
  # test ve araçlar
  "testthat", "callr", "httr2", "renv"
)
renv::snapshot(
  project = getwd(), lockfile = "renv.lock", packages = pkgs,
  library = .libPaths()[1], prompt = FALSE, force = TRUE
)
