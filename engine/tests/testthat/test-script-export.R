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
