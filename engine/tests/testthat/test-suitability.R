# M3 — KMO, Bartlett ve Mardia, psych fonksiyonlarıyla doğrudan karşılaştırılır.

hs <- example_ds("holzinger")
hs_x <- hs$clean$data[, hs$config$items$name]

test_that("Pearson: KMO, MSA, Bartlett ve Mardia psych ile birebir aynı (HS1939)", {
  rec <- analysis_suitability(hs$clean$data, hs$config, list(correlation = "pearson"), hs$hash)
  R <- stats::cor(hs_x)
  k <- psych::KMO(R)
  b <- psych::cortest.bartlett(R, n = nrow(hs_x))
  m <- psych::mardia(hs_x, plot = FALSE)
  expect_identical(rec$results$kmo, k$MSA)
  expect_identical(unlist(rec$results$msa), k$MSAi[names(hs_x)])
  expect_identical(rec$results$bartlett$chisq, b$chisq)
  expect_identical(rec$results$bartlett$df, b$df)
  expect_identical(rec$results$bartlett$p, b$p.value)
  expect_identical(rec$results$mardia$b1p, m$b1p)
  expect_identical(rec$results$mardia$b2p, m$b2p)
  expect_identical(rec$results$mardia$p_kurt, m$p.kurt)
})

test_that("polikorik: KMO ve Bartlett psych::polychoric matrisiyle aynı (bfi, 10 madde)", {
  items <- c(paste0("N", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items)
  x <- b10$clean$data[, b10$config$items$name]  # motorla aynı madde sırası (veri setindeki sütun sırası)
  rec <- analysis_suitability(b10$clean$data, b10$config, list(correlation = "polychoric"), b10$hash)
  R <- suppressWarnings(psych::polychoric(x, correct = 0.5))$rho
  expect_identical(rec$results$kmo, psych::KMO(R)$MSA)
  expect_identical(rec$results$bartlett$chisq, psych::cortest.bartlett(R, n = nrow(x))$chisq)
  expect_match(rec$tables[[1]]$note_tr, "normal kuram", fixed = TRUE)
})

test_that("polikorik, kategori aralığı tanımsız maddelerde reddedilir", {
  e <- tryCatch(analysis_suitability(hs$clean$data, hs$config, list(correlation = "polychoric"), hs$hash), error = function(e) e)
  expect_identical(e$code, "polychoric_needs_categories")
})

test_that("geçersiz ayar 422 döner", {
  e <- tryCatch(analysis_suitability(hs$clean$data, hs$config, list(correlation = "spearman"), hs$hash), error = function(e) e)
  expect_identical(e$code, "invalid_setting")
  expect_identical(e$status, 422L)
})
