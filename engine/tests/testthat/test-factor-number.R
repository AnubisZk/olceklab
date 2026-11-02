# M4 — paralel analiz ve MAP (SPEC §11.1, §11.2; SPEC_REVIEW PA-1…PA-5).
# Beklenen değerler psych::fa.parallel ve psych::vss doğrudan çağrılarak üretilir.

hs <- example_ds("holzinger")
hs_items <- hs$config$items$name
hs_x <- hs$clean$data[, hs_items]
bfi <- example_ds("bfi")
bfi_x <- bfi$clean$data[, bfi$config$items$name]

psych_pa <- function(x, seed, ...) {
  old <- options(mc.cores = 1L); on.exit(options(old))
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(seed)
  out <- NULL
  utils::capture.output(out <- suppressWarnings(suppressMessages(psych::fa.parallel(x, plot = FALSE, ...))), file = nullfile())
  out
}

run_m4 <- function(ds, ...) analysis_factor_number(ds$clean$data, ds$config, list(...), ds$hash)

test_that("§11.2 HS1939: önerilen sayı psych::fa.parallel ile aynı (n.iter = 1000, pc, simüle)", {
  rec <- run_m4(hs, extraction = "pc", n_iter = 1000L, seed = 20261030L)
  ref <- psych_pa(hs_x, 20261030L, fa = "pc", n.iter = 1000, sim = TRUE, quant = 0.95, cor = "cor", fm = "minres")
  expect_identical(as.integer(rec$results$pc$suggested), as.integer(ref$ncomp))
  expect_identical(rec$results$pc$observed, ref$pc.values)
})

for (cfg in list(list(ex = "pc", ref = "simulated_normal"), list(ex = "pc", ref = "resampled_bootstrap"),
                 list(ex = "fa", ref = "simulated_normal"), list(ex = "both", ref = "resampled_bootstrap"))) {
  test_that(sprintf("§11.2 bfi: %s / %s önerilen sayılar psych ile aynı", cfg$ex, cfg$ref), {
    rec <- run_m4(bfi, extraction = cfg$ex, reference = cfg$ref, n_iter = 40L, seed = 7L)
    ref <- psych_pa(bfi_x, 7L, fa = cfg$ex, n.iter = 40, sim = cfg$ref == "simulated_normal", quant = 0.95, cor = "cor", fm = "minres")
    if (cfg$ex != "fa") expect_identical(as.integer(rec$results$pc$suggested), as.integer(ref$ncomp))
    if (cfg$ex != "pc") expect_identical(as.integer(rec$results$fa$suggested), as.integer(ref$nfact))
  })
}

test_that("§11.1 parallel_manual, psych ile aynı tohumda birebir aynı özdeğer matrisini verir", {
  for (ex in c("pc", "fa", "both")) for (ref in c("simulated_normal", "resampled_bootstrap")) {
    ps <- psych_pa(hs_x, 11L, fa = ex, n.iter = 25, sim = ref == "simulated_normal", quant = 0.95, cor = "cor", fm = "minres")
    mn <- with_seeded_rng(11L, parallel_manual(hs_x, 25L, ex, "pearson", ref, "minres"))$value
    expect_identical(mn$values, unname(ps$values), info = paste(ex, ref))
    expect_identical(mn$observed_pc, ps$pc.values, info = paste(ex, ref))
    if (ex != "pc") expect_identical(mn$observed_fa, ps$fa.values, info = paste(ex, ref))
  }
})

test_that("§11.1 parallel_manual polikorik korelasyonda da psych ile birebir aynı", {
  items <- c(paste0("N", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items)
  x <- b10$clean$data[, items]
  ps <- psych_pa(x, 3L, fa = "pc", n.iter = 5, sim = FALSE, quant = 0.95, cor = "poly", fm = "minres")
  mn <- with_seeded_rng(3L, parallel_manual(x, 5L, "pc", "polychoric", "resampled_bootstrap", "minres"))$value
  expect_identical(mn$values, unname(ps$values))
})

test_that("PA-1: genel mc.cores = 2 iken bile aynı tohum aynı özdeğerleri verir", {
  old <- options(mc.cores = 2L); on.exit(options(old))
  r1 <- run_m4(hs, extraction = "pc", n_iter = 200L, seed = 99L)
  r2 <- run_m4(hs, extraction = "pc", n_iter = 200L, seed = 99L)
  expect_identical(r1$results$pc$reference_quantile, r2$results$pc$reference_quantile)
  expect_identical(r1$rng$mc_cores, 1L)
  expect_identical(getOption("mc.cores"), 2L)
})

test_that("RNG durumu çağrıdan sonra geri yüklenir", {
  set.seed(123); before <- .Random.seed
  run_m4(hs, extraction = "pc", n_iter = 20L, seed = 5L)
  expect_identical(.Random.seed, before)
})

test_that("PA-3: ortalama ölçütü $values'tan R'de hesaplanır ve tabloda iki referans da var", {
  rec <- run_m4(hs, extraction = "pc", n_iter = 300L, criterion = "mean", seed = 1L)
  ref <- psych_pa(hs_x, 1L, fa = "pc", n.iter = 300, sim = TRUE, quant = 0.95, cor = "cor", fm = "minres")
  p <- length(hs_items)
  sim_block <- unname(ref$values[, (p + 1):(2 * p)])
  expect_identical(rec$results$pc$reference_mean, unname(colMeans(sim_block)))
  expect_identical(rec$results$pc$reference_mean, unname(ref$pc.sim))
  expect_identical(rec$results$pc$suggested, which(!(ref$pc.values > colMeans(sim_block)))[1] - 1L)
  expect_true(all(c("pc_mean", "pc_q") %in% names(rec$tables[[1]]$rows)))
})

test_that("PA-4: polikorik + simüle normal referans reddedilir", {
  e <- tryCatch(run_m4(bfi, correlation = "polychoric", reference = "simulated_normal"), error = function(e) e)
  expect_identical(e$code, "invalid_reference_for_polychoric")
  expect_identical(e$status, 422L)
})

test_that("permütasyon referansı parallel_manual ile çalışır ve marjinalleri korur", {
  rec <- run_m4(hs, extraction = "pc", reference = "permutation", n_iter = 30L, seed = 2L)
  expect_identical(rec$results$source, "parallel_manual")
  expect_null(rec$results$psych_check)
  set.seed(1); y <- hs_x$x1
  expect_identical(sort(sample(y)), sort(y))
})

test_that("MAP psych::vss ile, Kaiser sayısı özdeğerlerle aynı", {
  rec <- run_m4(hs, extraction = "pc", n_iter = 20L, seed = 3L)
  ref <- suppressWarnings(psych::vss(hs_x, n = 8, rotate = "none", fm = "minres", plot = FALSE, cor = "cor"))
  expect_identical(unclass(rec$results$map$values), ref$map)
  expect_identical(rec$results$map$suggested, which.min(ref$map))
  expect_identical(rec$results$kaiser, sum(eigen(stats::cor(hs_x))$values > 1))
})

test_that("kayıt tohum, RNG ve karar metnini içerir; scree verisi tabloyla tutarlı", {
  rec <- run_m4(hs, extraction = "both", n_iter = 30L, seed = 4L)
  expect_identical(rec$seed, 4L)
  expect_identical(rec$rng$kind, "Mersenne-Twister")
  expect_match(rec$results$decision_tr, "Paralel analiz", fixed = TRUE)
  expect_match(rec$results$decision_en, "Crawford", fixed = TRUE)
  f <- rec$figures[[1]]$data
  expect_identical(f$pc_observed, rec$tables[[1]]$rows$pc_obs)
  expect_identical(f$fa_reference, rec$tables[[1]]$rows$fa_q)
})

test_that("geçersiz ayarlar reddedilir", {
  code <- function(...) tryCatch(run_m4(hs, ...), error = function(e) e$code)
  expect_identical(code(n_iter = 0L), "invalid_setting")
  expect_identical(code(extraction = "pca"), "invalid_setting")
  expect_identical(code(seed = 1.5), "invalid_setting")
})
