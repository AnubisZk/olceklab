# SPEC §11.3 — BİDEKÇET regresyon testleri (Faz 1 satırları). Yalnızca yerelde, veri varsa çalışır.
# Yapılandırma: engine/tests/private/bidekcet.json (örnek: bidekcet.example.json). Veri depoya girmez.
# Beklenen değerler SPEC §11.3'ten alınmıştır ve raporlandıkları basamakta karşılaştırılır (SPEC §11.1, REP-2).

cfg_path <- file.path(engine_dir, "tests", "private", "bidekcet.json")

spec_113 <- list(
  ortaokul = list(n_raw = 253L, n_final = 250L, removed = c(straightline = 3L), alpha = 0.794, kmo = 0.805, pa_pc = 2L),
  lise = list(n_raw = 279L, n_final = 256L, removed = c(invalid_group = 2L, missing = 5L, straightline = 16L),
              alpha = 0.836, kmo = 0.821, pa_pc = 2L)
)

at_reported_precision <- function(got, ref, digits) abs(got - ref) <= 0.5 * 10^(-digits) + 1e-12

load_private <- function(level) {
  cfg <- jsonlite::fromJSON(cfg_path, simplifyVector = TRUE)[[level]]
  path <- file.path(engine_dir, "tests", "private", cfg$file)
  if (!file.exists(path)) testthat::skip(sprintf("%s veri dosyası yok: %s", level, cfg$file))
  up <- parse_upload(readBin(path, "raw", file.size(path)), basename(path))
  conf <- build_config(up$data, cfg)
  out <- analysis_clean(up$data, conf, if (is.null(cfg$rules)) list() else cfg$rules, up$hash)
  list(cfg = cfg, conf = conf, out = out)
}

for (level in names(spec_113)) {
  test_that(sprintf("§11.3 %s: temizleme, alfa, KMO ve paralel analiz", level), {
    skip_if_not(file.exists(cfg_path), "BİDEKÇET yapılandırması yok (tests/private/bidekcet.json); KVKK gereği veri depoda değil")
    p <- load_private(level)
    ref <- spec_113[[level]]
    cl <- p$out$clean
    expect_identical(cl$n_raw, ref$n_raw)
    expect_identical(cl$n_final, ref$n_final)
    got <- stats::setNames(cl$steps$removed, cl$steps$step)
    for (k in names(ref$removed)) expect_identical(got[[k]], ref$removed[[k]], info = k)
    expect_identical(sum(got) - sum(ref$removed), 0L)

    item <- analysis_item(cl$data, p$conf, list(), "h")
    expect_true(at_reported_precision(item$results$alpha, ref$alpha, 3), info = sprintf("alfa = %.6f", item$results$alpha))
    suit <- analysis_suitability(cl$data, p$conf, list(correlation = "pearson"), "h")
    expect_true(at_reported_precision(suit$results$kmo, ref$kmo, 3), info = sprintf("KMO = %.6f", suit$results$kmo))
    pa <- analysis_factor_number(cl$data, p$conf, list(extraction = "pc", n_iter = 1000L, seed = 20261030L), "h")
    expect_identical(as.integer(pa$results$pc$suggested), ref$pa_pc)
  })
}
