# M12 — üretilen R betiği ayrı bir R sürecinde çalışır ve motorla aynı sayıları verir.

hs <- example_ds("holzinger")

test_that("M4 betiği (örnek veri) bağımsız çalışır ve aynı özdeğerleri verir", {
  rec <- analysis_factor_number(hs$clean$data, hs$config, list(extraction = "pc", n_iter = 50L, seed = 8L), hs$hash)
  script <- build_r_script("factor_number", hs, rec$settings, rec$seed)
  out <- run_script(script)
  p <- length(hs$config$items$name)
  expect_identical(unname(colMeans(out$values[, (p + 1):(2 * p)])), rec$results$pc$reference_mean)
  expect_identical(as.integer(out$ncomp), as.integer(rec$results$pc$suggested))
  expect_identical(out$map, unclass(rec$results$map$values))
  expect_identical(apply(unname(out$values[, (p + 1):(2 * p)]), 2, stats::quantile, 0.95), rec$results$pc$reference_quantile)
})

test_that("M4 permütasyon betiği motorun parallel_manual fonksiyonunu içerir ve aynı sonucu verir", {
  rec <- analysis_factor_number(hs$clean$data, hs$config, list(extraction = "pc", reference = "permutation", n_iter = 20L, seed = 9L), hs$hash)
  out <- run_script(build_r_script("factor_number", hs, rec$settings, rec$seed))
  p <- length(hs$config$items$name)
  expect_identical(apply(out$values[, 1:p], 2, stats::quantile, 0.95), rec$results$pc$reference_quantile)
})

test_that("M2 ve M3 betikleri yüklenen CSV dosyasıyla bağımsız çalışır", {
  items <- c(paste0("N", 1:5), paste0("C", 1:5))
  df <- psych::bfi[, c(items, "gender")]
  csv <- tempfile(fileext = ".csv")
  on.exit(unlink(csv), add = TRUE)
  utils::write.csv(df, csv, row.names = FALSE, na = "")
  raw <- readBin(csv, "raw", file.size(csv))
  up <- parse_upload(raw, "bfi10.csv")
  ds <- list(data = up$data, hash = up$hash, filename = up$filename, source = list(type = "upload"))
  ds$config <- build_config(ds$data, list(
    roles = c(stats::setNames(as.list(rep("item", 10)), items), list(gender = "group")),
    items = lapply(stats::setNames(items, items), function(i) list(min = 1, max = 6, reverse = i %in% c("C4", "C5")))))
  ds$clean_rules <- list(straightline = FALSE)
  ds$clean <- clean_dataset(ds$data, ds$config, ds$clean_rules)

  r2 <- analysis_item(ds$clean$data, ds$config, list(), ds$hash)
  s2 <- sub("VERI_DOSYASI", csv, build_r_script("item_analysis", ds, r2$settings), fixed = TRUE)
  o2 <- run_script(s2)
  expect_identical(o2$alpha, r2$results$alpha)
  expect_identical(unname(o2$r_drop), r2$results$items$r_drop)

  r3 <- analysis_suitability(ds$clean$data, ds$config, list(correlation = "pearson"), ds$hash)
  o3 <- run_script(sub("VERI_DOSYASI", csv, build_r_script("suitability", ds, r3$settings), fixed = TRUE))
  expect_identical(o3$kmo, r3$results$kmo)
  expect_identical(o3$bartlett$chisq, r3$results$bartlett$chisq)
})

test_that("betik sürüm denetimi ve veri özeti içerir", {
  rec <- analysis_item(hs$clean$data, hs$config, list(), hs$hash)
  s <- build_r_script("item_analysis", hs, rec$settings)
  expect_match(s, hs$hash, fixed = TRUE)
  expect_match(s, sprintf("psych = \"%s\"", as.character(utils::packageVersion("psych"))), fixed = TRUE)
  expect_match(s, "clean_dataset <- function", fixed = TRUE)
})

# --- Faz 2: M5, M6, M7 ----------------------------------------------------------

bfi10 <- example_ds("bfi", items = c(paste0("A", 1:5), paste0("C", 1:5)))
m_ac <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
m3 <- default_model_from_subscales(hs$config)

test_that("M5 betiği ayrı süreçte psych::fa ile aynı yükleri ve uyumu verir", {
  rec <- analysis_efa(bfi10$clean$data, bfi10$config, list(nfactors = 2, rotate = "geominQ", seed = 4), bfi10$hash)
  out <- run_script(build_r_script("efa", bfi10, rec$settings, rec$seed))
  L <- do.call(cbind, lapply(rec$results$loadings, as.numeric))
  expect_identical(unname(out$loadings), unname(L))
  expect_identical(unname(out$fit$chisq), rec$results$fit$chisq)
  expect_identical(unname(out$fit$tli), rec$results$fit$tli)
})

test_that("M6 betiği (ML, wishart, Bollen–Stine) ayrı süreçte aynı uyum ve aynı bootstrap p değerini verir", {
  rec <- analysis_cfa(hs$clean$data, hs$config, list(model = m3, likelihood = "wishart", bootstrap = 100, seed = 12), hs$hash)
  script <- build_r_script("cfa", hs, rec$settings, rec$seed, rec$results)
  expect_match(script, "likelihood = \"wishart\"", fixed = TRUE)
  expect_match(script, "iseed = 12L", fixed = TRUE)
  out <- run_script(script)
  expect_identical(unname(out$fit[["chisq"]]), rec$results$fit$chisq)
  expect_identical(unname(out$fit[["cfi"]]), rec$results$fit$cfi)
  expect_identical(out$loadings$std.all, rec$results$loadings$std)
  expect_identical(out$bollen_stine$pvalue, rec$results$bollen_stine$pvalue)
  expect_identical(out$mi$mi, rec$results$modification_indices$mi)
})

test_that("M6 WLSMV betiği aynı ölçeklenmiş ve dayanıklı indeksleri verir", {
  rec <- analysis_cfa(bfi10$clean$data, bfi10$config, list(model = m_ac, estimator = "WLSMV"), bfi10$hash)
  out <- run_script(build_r_script("cfa", bfi10, rec$settings, rec$seed, rec$results))
  expect_identical(unname(out$fit[["cfi.scaled"]]), rec$results$fit$cfi_scaled)
  expect_identical(unname(out$fit[["cfi.robust"]]), rec$results$fit$cfi_robust)
})

test_that("M6 karşılaştırma betiği aynı iç içelik matrisini ve fark testlerini verir", {
  two <- list(factors = list(list(name = "vt", items = paste0("x", 1:6)), list(name = "speed", items = c("x7", "x8", "x9"))))
  rec <- analysis_cfa_compare(hs$clean$data, hs$config, list(estimator = "MLR", models = list(
    list(name = "Üç faktör", model = m3), list(name = "İki faktör", model = two))), hs$hash)
  out <- run_script(build_r_script("cfa_compare", hs, rec$settings, rec$seed, rec$results))
  expect_identical(unname(out$ic_ice), rec$results$nesting$matrix)
  t <- rec$results$tests[[1]]
  got <- out$testler[[1]]
  expect_identical(got[["Chisq diff"]], t$chisq_diff)
  expect_identical(got[["Pr(>Chisq)"]], t$p)
  expect_identical(unname(out$fit[["İki faktör"]][["cfi.scaled"]]), rec$results$fit[["İki faktör"]]$cfi_scaled)
})

test_that("M7 betiği aynı α, ω, AVE ve HTMT değerlerini verir", {
  rec <- analysis_reliability(bfi10$clean$data, bfi10$config, list(model = m_ac, estimator = "WLSMV", obs_var = FALSE,
                                                                  htmt = list(correlation = "polychoric")), bfi10$hash)
  out <- run_script(build_r_script("reliability", bfi10, rec$settings, rec$seed, rec$results))
  expect_identical(unname(out$alfa[["A"]]), rec$results$alpha$A)
  expect_identical(as.numeric(out$omega[["C"]]), rec$results$omega$C)
  expect_identical(as.numeric(out$ave[["A"]]), rec$results$ave$A)
  expect_identical(unclass(out$htmt)["A", "C"], rec$results$htmt$A$C)
})
