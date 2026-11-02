# M5 — AFA. Beklenen değerler psych::fa doğrudan, aynı RNG türü, tohum ve mc.cores = 1 ile çağrılarak üretilir.

bfi <- example_ds("bfi")
bfi_items <- bfi$config$items$name
bfi_x <- bfi$clean$data[, bfi_items]

ref_fa <- function(x, seed, ...) {
  old <- options(mc.cores = 1L); on.exit(options(old), add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(seed)
  quiet(psych::fa(x, ..., correct = 0.5, scores = "none", warnings = TRUE))$value
}

col_mat <- function(lst) do.call(cbind, lapply(lst, as.numeric))

test_that("bfi, 5 faktör, minres + oblimin: yükler, h², Phi, açıklanan varyans ve uyum psych::fa ile birebir aynı", {
  rec <- analysis_efa(bfi$clean$data, bfi$config, list(nfactors = 5, seed = 11), bfi$hash)
  f <- ref_fa(bfi_x, 11, nfactors = 5, fm = "minres", rotate = "oblimin", cor = "cor", n.rotations = 20)
  L <- unclass(f$loadings)[bfi_items, ]
  r <- rec$results
  expect_identical(as.character(r$factors), colnames(L))
  expect_identical(unname(col_mat(r$loadings)), unname(L))
  expect_identical(as.numeric(r$communality), unname(f$communality[bfi_items]))
  expect_identical(as.numeric(r$uniqueness), unname(f$uniquenesses[bfi_items]))
  expect_identical(unname(col_mat(r$phi)), unname(f$Phi[colnames(L), colnames(L)]))
  expect_identical(as.numeric(r$variance$ss), unname(f$Vaccounted["SS loadings", colnames(L)]))
  expect_identical(r$fit$chisq, unname(f$STATISTIC))
  expect_identical(r$fit$df, unname(f$dof))
  expect_identical(r$fit$tli, unname(f$TLI))
  expect_identical(r$fit$rmsea, unname(f$RMSEA["RMSEA"]))
  expect_identical(r$fit$rmsr, unname(f$rms))
  expect_identical(as.character(r$sorted_items), rownames(psych::fa.sort(f)$loadings))
  expect_identical(rec$seed, 11L)
  expect_identical(rec$rng$kind, "Mersenne-Twister")
  expect_identical(rec$settings$n_rotations, 20L)
})

test_that("diğer kestirim ve döndürme seçenekleri psych::fa ile aynı (ml/varimax, pa/promax, uls/geominQ, minres/none)", {
  combos <- list(c("ml", "varimax"), c("pa", "promax"), c("uls", "geominQ"), c("minres", "none"))
  for (cb in combos) {
    rec <- analysis_efa(bfi$clean$data, bfi$config, list(nfactors = 5, fm = cb[1], rotate = cb[2], seed = 3, n_rotations = 5), bfi$hash)
    f <- ref_fa(bfi_x, 3, nfactors = 5, fm = cb[1], rotate = cb[2], cor = "cor", n.rotations = 5)
    expect_identical(unname(col_mat(rec$results$loadings)), unname(unclass(f$loadings)[bfi_items, ]), info = paste(cb, collapse = "/"))
    expect_identical(isTRUE(rec$results$oblique), cb[2] %in% c("promax", "geominQ"), info = paste(cb, collapse = "/"))
    expect_identical(is.null(rec$results$phi), !(cb[2] %in% c("promax", "geominQ")), info = paste(cb, collapse = "/"))
  }
})

test_that("polikorik korelasyonla AFA psych::fa(cor = 'poly', correct = 0.5) ile aynı", {
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  x <- b10$clean$data[, b10$config$items$name]
  rec <- analysis_efa(b10$clean$data, b10$config, list(nfactors = 2, correlation = "polychoric", seed = 5), b10$hash)
  f <- ref_fa(x, 5, nfactors = 2, fm = "minres", rotate = "oblimin", cor = "poly", n.rotations = 20)
  expect_identical(unname(col_mat(rec$results$loadings)), unname(unclass(f$loadings)[b10$config$items$name, ]))
  expect_match(rec$tables[[length(rec$tables)]]$note_tr, "yaklaşıktır", fixed = TRUE)
})

test_that("aynı tohum aynı sonucu verir; tohum ve RNG türü kayda yazılır (EFA-2)", {
  a <- analysis_efa(bfi$clean$data, bfi$config, list(nfactors = 5, rotate = "geominQ", seed = 99), bfi$hash)
  b <- analysis_efa(bfi$clean$data, bfi$config, list(nfactors = 5, rotate = "geominQ", seed = 99), bfi$hash)
  expect_identical(a$results$loadings, b$results$loadings)
  expect_identical(a$seed, 99L)
  expect_identical(a$rng$mc_cores, 1L)
  expect_match(a$tables[[1]]$note_tr, "n.rotations = 20, tohum = 99", fixed = TRUE)
})

test_that("polikorik + ml için EFA-1 uyarısı verilir", {
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  rec <- analysis_efa(b10$clean$data, b10$config, list(nfactors = 2, correlation = "polychoric", fm = "ml", seed = 1), b10$hash)
  expect_true("poly_with_ml" %in% vapply(rec$warnings, `[[`, "", "code"))
})

test_that("çapraz yük ve belirgin yükü olmayan madde uyarıları eşikle tutarlı", {
  rec <- analysis_efa(bfi$clean$data, bfi$config, list(nfactors = 5, threshold = 0.25, seed = 2), bfi$hash)
  L <- col_mat(rec$results$loadings)
  sal <- abs(L) >= 0.25
  cross <- bfi_items[rowSums(sal) >= 2]
  none <- bfi_items[rowSums(sal) == 0]
  codes <- vapply(rec$warnings, `[[`, "", "code")
  expect_identical("cross_loading" %in% codes, length(cross) > 0)
  expect_identical("no_salient_loading" %in% codes, length(none) > 0)
  if (length(cross)) {
    w <- rec$warnings[[which(codes == "cross_loading")]]
    for (i in cross) expect_match(w$message_tr, paste0("\\b", i, "\\b"))
  }
  expect_identical(unname(col_mat(rec$results$salient) == 1), unname(sal))
})

test_that("Heywood durumu uyarısı psych'in ortak varyanslarıyla tutarlı (HS1939, 4 faktör, ml)", {
  hs <- example_ds("holzinger")
  rec <- analysis_efa(hs$clean$data, hs$config, list(nfactors = 4, fm = "ml", seed = 1), hs$hash)
  h2 <- as.numeric(rec$results$communality)
  hey <- hs$config$items$name[h2 >= 0.995]
  expect_gt(length(hey), 0)
  w <- Filter(function(w) w$code == "heywood", rec$warnings)
  expect_length(w, 1L)
  for (i in hey) expect_match(w[[1]]$message_tr, i, fixed = TRUE)
})

test_that("serbestlik derecesi negatifse uyarılır; psych hatası 422 ile döner", {
  hs <- example_ds("holzinger", items = paste0("x", 1:6))
  rec <- analysis_efa(hs$clean$data, hs$config, list(nfactors = 4, seed = 1), hs$hash)
  expect_true("negative_df" %in% vapply(rec$warnings, `[[`, "", "code"))
  h9 <- example_ds("holzinger")
  e <- tryCatch(analysis_efa(h9$clean$data, h9$config, list(nfactors = 4, fm = "pa", seed = 1), h9$hash), error = function(e) e)
  expect_identical(e$code, "efa_failed")
  expect_identical(e$status, 422L)
  expect_true(nzchar(e$detail))
})

test_that("geçersiz ayarlar 422 ile reddedilir", {
  code <- function(s, ds = bfi) tryCatch({ analysis_efa(ds$clean$data, ds$config, s, ds$hash); "ok" }, error = function(e) e$code)
  expect_identical(code(list(nfactors = 25)), "invalid_setting")
  expect_identical(code(list(nfactors = 0)), "invalid_setting")
  expect_identical(code(list(nfactors = 2, fm = "wls")), "invalid_setting")
  expect_identical(code(list(nfactors = 2, rotate = "quartimin")), "invalid_setting")
  hs <- example_ds("holzinger")
  expect_identical(code(list(nfactors = 2, correlation = "polychoric"), hs), "polychoric_needs_categories")
})

test_that("tablolar R'de biçimlenir: yükler baştaki sıfırsız, uyum tablosunda güven aralığı", {
  rec <- analysis_efa(bfi$clean$data, bfi$config, list(nfactors = 5, seed = 11), bfi$hash)
  t1 <- rec$tables[[1]]
  f1 <- unlist(rec$results$factors)[1]
  expect_identical(t1$rows_fmt$tr[[f1]][1], fmt_num(rec$results$loadings[[f1]][1], 3, "tr", TRUE))
  expect_identical(t1$rows_fmt$en[[f1]][1], fmt_num(rec$results$loadings[[f1]][1], 3, "en", TRUE))
  fit <- rec$tables[[length(rec$tables)]]
  expect_identical(fit$rows_fmt$tr$value[fit$rows$key == "rmsea_ci"],
                   fmt_ci(rec$results$fit$rmsea_lower, rec$results$fit$rmsea_upper, 3, "tr", TRUE))
  expect_match(fit$rows_fmt$tr$value[fit$rows$key == "rmsea_ci"], "^\\[,[0-9]{3}; ,[0-9]{3}\\]$")
  expect_match(fit$rows_fmt$en$value[fit$rows$key == "rmsea_ci"], "^\\[\\.[0-9]{3}, \\.[0-9]{3}\\]$")
})
