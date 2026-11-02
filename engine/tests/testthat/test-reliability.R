# M7 — Güvenirlik ve geçerlik. Beklenen değerler psych::alpha ve semTools fonksiyonları doğrudan çağrılarak
# üretilir; ω ve AVE ayrıca lavaan kestirimlerinden elle yeniden hesaplanır (obs.var farkının belgelenmesi).

hs <- example_ds("holzinger")
hs_x <- hs$clean$data[, hs$config$items$name]
m3 <- default_model_from_subscales(hs$config)
s3 <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
run_rel <- function(s, ds = hs) analysis_reliability(ds$clean$data, ds$config, s, ds$hash)
num <- function(v) stats::setNames(as.numeric(unclass(v)), names(v))

test_that("α, ω, AVE ve HTMT psych ve semTools ile birebir aynı (HS1939, ML, varsayılan ayarlar)", {
  rec <- run_rel(list(model = m3))
  fit <- lavaan::cfa(s3, hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  om <- num(semTools::compRelSEM(fit, obs.var = TRUE, ord.scale = TRUE, simplify = TRUE))
  av <- num(semTools::AVE(fit, obs.var = TRUE))
  ht <- unclass(semTools::htmt(s3, data = hs_x, htmt2 = FALSE, absolute = TRUE))
  for (f in c("visual", "textual", "speed")) {
    its <- m3$factors[[match(f, c("visual", "textual", "speed"))]]$items
    expect_identical(rec$results$alpha[[f]], psych::alpha(hs_x[, its], check.keys = FALSE, warnings = FALSE)$total$raw_alpha, info = f)
    expect_identical(rec$results$omega[[f]], om[[f]], info = f)
    expect_identical(rec$results$ave[[f]], av[[f]], info = f)
  }
  expect_identical(rec$results$alpha_total, psych::alpha(hs_x, check.keys = FALSE, warnings = FALSE)$total$raw_alpha)
  expect_identical(rec$results$htmt$visual$textual, ht["visual", "textual"])
  expect_identical(rec$results$htmt$speed$textual, ht["speed", "textual"])
  expect_identical(rec$settings$htmt, list(htmt2 = FALSE, absolute = TRUE, correlation = "pearson"))
  expect_true(rec$settings$obs_var)
})

test_that("obs.var = TRUE ve FALSE: ω ve AVE, formülleriyle lavaan kestirimlerinden elle yeniden hesaplanır", {
  fit <- lavaan::cfa(s3, hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  est <- lavaan::lavInspect(fit, "est")
  S <- lavaan::lavInspect(fit, "sampstat")$cov
  Sig <- lavaan::lavInspect(fit, "implied")$cov
  a <- run_rel(list(model = m3, obs_var = TRUE))
  b <- run_rel(list(model = m3, obs_var = FALSE))
  for (f in c("visual", "textual", "speed")) {
    its <- rownames(est$lambda)[est$lambda[, f] != 0]
    lam <- est$lambda[its, f]; psi <- est$psi[f, f]; th <- diag(est$theta)[its]
    true_var <- sum(lam)^2 * psi
    # obs.var = TRUE: payda gözlenen toplam puan varyansı 1'S1
    expect_equal(a$results$omega[[f]], true_var / sum(S[its, its]), tolerance = 1e-12, info = f)
    # obs.var = FALSE: payda örtük varyans 1'Σ(θ)1; hata kovaryansı yokken McDonald ω = (Σλ)²ψ / ((Σλ)²ψ + Σθ)
    expect_equal(b$results$omega[[f]], true_var / sum(Sig[its, its]), tolerance = 1e-12, info = f)
    expect_equal(b$results$omega[[f]], true_var / (true_var + sum(th)), tolerance = 1e-12, info = f)
    # AVE = Σλ²ψ / Σ diag(Σ̂)
    expect_equal(a$results$ave[[f]], sum(lam^2 * psi) / sum(diag(S)[its]), tolerance = 1e-12, info = f)
    expect_equal(b$results$ave[[f]], sum(lam^2 * psi) / sum(diag(Sig)[its]), tolerance = 1e-12, info = f)
  }
  expect_false(isTRUE(all.equal(a$results$omega$visual, b$results$omega$visual)))
  expect_match(a$tables[[1]]$note_tr, "gözlenen (doymuş model) toplam puan varyansı", fixed = TRUE)
  expect_match(b$tables[[1]]$note_tr, "McDonald (1999)", fixed = TRUE)
})

test_that("hata kovaryansı varken obs.var = FALSE paydası kovaryansı içerir; skaler McDonald formülünden ayrılır", {
  mc <- c(m3, list(covariances = list(c("x7", "x8"))))
  b <- run_rel(list(model = mc, obs_var = FALSE))
  fit <- lavaan::cfa(paste0(s3, "\nx7 ~~ x8"), hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  est <- lavaan::lavInspect(fit, "est")
  its <- c("x7", "x8", "x9")
  lam <- est$lambda[its, "speed"]; psi <- est$psi["speed", "speed"]
  tv <- sum(lam)^2 * psi
  expect_equal(b$results$omega$speed, tv / (tv + sum(diag(est$theta)[its]) + 2 * est$theta["x7", "x8"]), tolerance = 1e-12)
  expect_false(isTRUE(all.equal(b$results$omega$speed, tv / (tv + sum(diag(est$theta)[its])))))
})

test_that("WLSMV (bfi): ω ord.scale = TRUE, AVE ve polikorik HTMT semTools ile aynı", {
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  x <- b10$clean$data[, b10$config$items$name]
  mod <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  rec <- run_rel(list(model = mod, estimator = "WLSMV", htmt = list(correlation = "polychoric")), b10)
  syn <- "A =~ A1 + A2 + A3 + A4 + A5\nC =~ C1 + C2 + C3 + C4 + C5"
  fit <- lavaan::cfa(syn, x, estimator = "WLSMV", std.lv = FALSE, ordered = b10$config$items$name)
  om <- num(semTools::compRelSEM(fit, obs.var = TRUE, ord.scale = TRUE, simplify = TRUE))
  av <- num(semTools::AVE(fit, obs.var = TRUE))
  ht <- unclass(semTools::htmt(syn, data = x, ordered = b10$config$items$name, htmt2 = FALSE, absolute = TRUE))
  expect_identical(rec$results$omega$A, om[["A"]])
  expect_identical(rec$results$omega$C, om[["C"]])
  expect_identical(rec$results$ave$C, av[["C"]])
  expect_identical(rec$results$htmt$A$C, ht["A", "C"])
  expect_match(rec$tables[[1]]$note_tr, "Green ve Yang, 2009", fixed = TRUE)
  expect_match(rec$tables[[1]]$note_tr, "y*", fixed = TRUE)
})

test_that("HTMT seçenekleri (htmt2, absolute) semTools ile aynı; tanımsız değer uyarılır", {
  for (h2 in c(TRUE, FALSE)) for (ab in c(TRUE, FALSE)) {
    rec <- run_rel(list(model = m3, htmt = list(htmt2 = h2, absolute = ab)))
    ref <- unclass(semTools::htmt(s3, data = hs_x, htmt2 = h2, absolute = ab))
    expect_identical(rec$results$htmt$visual$speed, ref["visual", "speed"], info = paste(h2, ab))
  }
  # Ters maddeler yeniden kodlanmadan (bfi, ters kodlama kapalı) htmt2 = TRUE, absolute = FALSE → NaN
  b <- example_ds("bfi", items = c(paste0("A", 1:5), paste0("C", 1:5)), rules = list(reverse = FALSE))
  mod <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  rec <- run_rel(list(model = mod, htmt = list(htmt2 = TRUE, absolute = FALSE)), b)
  ref <- unclass(semTools::htmt("A =~ A1 + A2 + A3 + A4 + A5\nC =~ C1 + C2 + C3 + C4 + C5", data = b$clean$data, htmt2 = TRUE, absolute = FALSE))
  expect_identical(is.nan(rec$results$htmt$A$C), is.nan(ref["A", "C"]))
  if (is.nan(ref["A", "C"])) expect_true("htmt_undefined" %in% vapply(rec$warnings, `[[`, "", "code"))
})

test_that("eşikler ayarlanabilir; işaretler ve uyarılar eşiklerle tutarlı", {
  rec <- run_rel(list(model = m3, thresholds = list(cr = 0.65, ave = 0.40, htmt = 0.45)))
  om <- unlist(rec$results$omega); av <- unlist(rec$results$ave)
  t1 <- rec$tables[[1]]
  expect_identical(t1$rows$cr_ok[1:3], unname(om >= 0.65))
  expect_identical(t1$rows$ave_ok[1:3], unname(av >= 0.40))
  expect_identical(t1$rows_fmt$tr$cr_ok[1:3], unname(ifelse(om >= 0.65, "Evet", "Hayır")))
  expect_identical(t1$columns[[8]]$label_tr, "ω ≥ ,65")
  hi <- rec$results$htmt$visual$speed > 0.45
  expect_identical("high_htmt" %in% vapply(rec$warnings, `[[`, "", "code"), isTRUE(hi) || isTRUE(rec$results$htmt$visual$textual > 0.45))
  expect_identical(t1$rows_fmt$tr$factor[4], "Toplam (bütün maddeler)")
})

test_that("Fornell–Larcker: √AVE ve faktör korelasyonları lavInspect(std) ile aynı", {
  rec <- run_rel(list(model = m3))
  fit <- lavaan::cfa(s3, hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  psi <- lavaan::lavInspect(fit, "std")$psi
  expect_identical(rec$results$factor_correlations$visual$speed, psi["visual", "speed"])
  t3 <- rec$tables[[3]]
  expect_identical(t3$rows$visual[1], sqrt(rec$results$ave$visual))
  expect_identical(t3$rows_fmt$tr$speed[1], "")
})

test_that("tek faktörlü modelde HTMT ve Fornell–Larcker tablosu yoktur", {
  rec <- run_rel(list(model = list(factors = list(list(name = "g", items = paste0("x", 1:9))))))
  expect_length(rec$tables, 1L)
  expect_null(rec$results$htmt)
  # semTools tek bileşikte adsız değer döndürür; ω yine de raporlanmalı (tarayıcı akışında bulunan hata)
  fit <- lavaan::cfa("g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9", hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  expect_identical(rec$results$omega$g, as.numeric(semTools::compRelSEM(fit, simplify = TRUE)))
  expect_false(is.na(rec$results$omega$g))
  expect_identical(rec$tables[[1]]$rows_fmt$tr$omega[1], fmt_num(rec$results$omega$g, 3, "tr", TRUE))
})

test_that("ikinci düzey modelde güvenirlik birinci düzey faktörler için raporlanır", {
  rec <- run_rel(list(model = list(syntax = paste0(s3, "\ng =~ visual + textual + speed"))))
  expect_identical(as.character(rec$results$factors), c("visual", "textual", "speed"))
})
