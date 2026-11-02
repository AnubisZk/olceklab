# M8 — Ölçme değişmezliği. Beklenen değerler lavaan::cfa / semTools::measEq.syntax / lavTestLRT / lavTestScore
# doğrudan çağrılarak üretilir.

hs <- example_ds("holzinger")
hs_x <- hs$clean$data
m3 <- default_model_from_subscales(hs$config)
s3 <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
glab <- c("Pasteur", "Grant-White")
run_inv <- function(s, ds = hs) analysis_invariance(ds$clean$data, ds$config, s, ds$hash)
ref_fit <- function(eq = NULL, partial = NULL, ...) {
  a <- list(s3, data = hs_x, group = "school", group.label = glab, std.lv = TRUE, ...)
  if (length(eq)) a$group.equal <- eq
  if (length(partial)) a$group.partial <- partial
  do.call(lavaan::cfa, a)
}

test_that("sürekli (ML): her adımın uyumu ve ardışık χ² farkları lavaan ile birebir; iki SRMR da raporlanır", {
  rec <- run_inv(list(model = m3, include_strict = TRUE))
  f <- list(configural = ref_fit(), metric = ref_fit("loadings"), scalar = ref_fit(c("loadings", "intercepts")),
            strict = ref_fit(c("loadings", "intercepts", "residuals")))
  expect_identical(as.character(rec$results$steps), names(f))
  for (k in names(f)) {
    expect_identical(rec$results$fit[[k]]$chisq, as.numeric(lavaan::fitMeasures(f[[k]], "chisq")), info = k)
    expect_identical(rec$results$fit[[k]]$srmr, as.numeric(lavaan::fitMeasures(f[[k]], "srmr")), info = k)
    expect_identical(rec$results$fit[[k]]$srmr_bentler_nomean, as.numeric(lavaan::fitMeasures(f[[k]], "srmr_bentler_nomean")), info = k)
  }
  cm <- rec$results$comparisons
  for (k in 2:4) {
    ref <- lavaan::lavTestLRT(f[[k - 1]], f[[k]])
    expect_identical(cm$chisq_diff[k - 1], ref[2, "Chisq diff"])
    expect_identical(cm$df_diff[k - 1], ref[2, "Df diff"])
    expect_identical(cm$delta_cfi[k - 1], as.numeric(lavaan::fitMeasures(f[[k]], "cfi") - lavaan::fitMeasures(f[[k - 1]], "cfi")))
    expect_identical(cm$delta_srmr[k - 1], as.numeric(lavaan::fitMeasures(f[[k]], "srmr_bentler_nomean") - lavaan::fitMeasures(f[[k - 1]], "srmr_bentler_nomean")))
  }
  expect_identical(rec$settings$groups, I(glab))
})

test_that("kararlar ölçütlerle tutarlı; ΔSRMR eşiği yük adımında ,030, diğerlerinde ,010; birleşik kural", {
  rec <- run_inv(list(model = m3, include_strict = TRUE, rule = "and"))
  cm <- rec$results$comparisons; d <- rec$results$decisions
  expect_identical(d$cfi_ok, cm$delta_cfi >= -0.01)
  expect_identical(d$rmsea_ok, cm$delta_rmsea <= 0.015)
  expect_identical(d$srmr_lim, c(0.030, 0.010, 0.010))
  expect_identical(d$chisq_ok, cm$p >= 0.05)
  expect_identical(as.logical(rec$results$combined), d$cfi_ok & d$rmsea_ok)
  t2 <- rec$tables[[2]]
  expect_identical(t2$rows_fmt$tr$cfi_ok, ifelse(d$cfi_ok, "Sağlandı", "Sağlanmadı"))
  expect_match(t2$note_tr, "Cheung ve Rensvold, 2002", fixed = TRUE)
  custom <- run_inv(list(model = m3, criteria = list(cfi = -0.002)))
  expect_identical(custom$results$decisions$cfi_ok, custom$results$comparisons$delta_cfi >= -0.002)
})

test_that("kısmi değişmezlik: group.partial lavaan'a aynen geçer; sonuçlar aynı", {
  rec <- run_inv(list(model = m3, partial = c("x3~1", "visual=~x2")))
  sc <- ref_fit(c("loadings", "intercepts"), c("x3~1", "visual=~x2"))
  me <- ref_fit("loadings", c("x3~1", "visual=~x2"))
  expect_identical(rec$results$fit$scalar$chisq, as.numeric(lavaan::fitMeasures(sc, "chisq")))
  expect_identical(rec$results$fit$metric$chisq, as.numeric(lavaan::fitMeasures(me, "chisq")))
  expect_true("partial_data_driven" %in% vapply(rec$warnings, `[[`, "", "code"))
  expect_match(rec$tables[[1]]$note_tr, "x3~1, visual=~x2", fixed = TRUE)
  e <- tryCatch(run_inv(list(model = m3, partial = c("x3 ~ x4"))), error = function(e) e)
  expect_identical(e$code, "invalid_partial")
})

test_that("MLR: Satorra–Bentler (2001) farkı ve ölçeklenmiş Δ indeksleri", {
  rec <- run_inv(list(model = m3, estimator = "MLR"))
  a <- ref_fit(estimator = "MLR"); b <- ref_fit("loadings", estimator = "MLR")
  ref <- lavaan::lavTestLRT(a, b, method = "satorra.bentler.2001")
  expect_identical(rec$results$comparisons$chisq_diff[1], ref[2, "Chisq diff"])
  expect_identical(rec$results$comparisons$method[1], "satorra.bentler.2001")
  expect_identical(rec$results$comparisons$delta_cfi[1], as.numeric(lavaan::fitMeasures(b, "cfi.scaled") - lavaan::fitMeasures(a, "cfi.scaled")))
})

test_that("gizil ortalamalar: κ lavaan skaler modeliyle aynı; d (birleşik SS) elle hesaplananla aynı; model eşdeğer", {
  rec <- run_inv(list(model = m3))
  sc <- ref_fit(c("loadings", "intercepts"))
  pe <- lavaan::parameterEstimates(sc)
  n <- lavaan::lavInspect(sc, "nobs")
  lm <- rec$results$latent_means
  for (f in c("visual", "textual", "speed")) {
    k <- pe$est[pe$op == "~1" & pe$lhs == f & pe$group == 2]
    v2 <- pe$est[pe$op == "~~" & pe$lhs == f & pe$rhs == f & pe$group == 2]
    expect_equal(lm$kappa[lm$factor == f], k, tolerance = 1e-6, info = f)
    expect_equal(lm$d[lm$factor == f], k / sqrt(((n[1] - 1) * 1 + (n[2] - 1) * v2) / (n[1] + n[2] - 2)), tolerance = 1e-6, info = f)
  }
  expect_false(anyNA(lm$d_se))
  ref_sd <- run_inv(list(model = m3, d_sd = "reference"))
  expect_equal(ref_sd$results$latent_means$d, ref_sd$results$latent_means$kappa, tolerance = 1e-12)
  expect_match(rec$tables[[3]]$note_tr, "Hancock, 2001", fixed = TRUE)
})

test_that("gizil ortalamalar, bir faktörde iki değişmez madde kalmazsa kilitlenir (SPEC I-4)", {
  rec <- run_inv(list(model = m3, partial = c("x1~1", "x2~1")))
  expect_false(rec$results$latent_means_available)
  expect_true("latent_means_locked" %in% vapply(rec$warnings, `[[`, "", "code"))
  expect_length(rec$tables, 2L)
})

test_that("referans grup seçilebilir; grup sırası lavaan'a group.label ile verilir", {
  rec <- run_inv(list(model = m3, reference_group = "Grant-White"))
  expect_identical(as.character(rec$results$groups), c("Grant-White", "Pasteur"))
  f <- lavaan::cfa(s3, data = hs_x, group = "school", group.label = c("Grant-White", "Pasteur"), std.lv = TRUE,
                   group.equal = c("loadings", "intercepts"))
  pe <- lavaan::parameterEstimates(f)
  expect_equal(rec$results$latent_means$kappa[1], pe$est[pe$op == "~1" & pe$lhs == "visual" & pe$group == 2], tolerance = 1e-6)
})

test_that("kategorik (WLSMV, theta, Wu–Estabrook): adımlar measEq.syntax + lavaan::cfa ile birebir", {
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  mod <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  rec <- run_inv(list(model = mod, approach = "categorical"), b10)
  x <- b10$clean$data
  x$gender <- as.character(x$gender)
  syn <- "A =~ A1 + A2 + A3 + A4 + A5\nC =~ C1 + C2 + C3 + C4 + C5"
  fit_step <- function(eq) {
    s <- semTools::measEq.syntax(configural.model = syn, data = x, ordered = items10, parameterization = "theta",
                                 ID.fac = "std.lv", ID.cat = "Wu.Estabrook.2016", group = "gender", group.label = c("1", "2"),
                                 group.equal = if (length(eq)) eq else "")
    lavaan::cfa(as.character(s), data = x, group = "gender", group.label = c("1", "2"), ordered = items10,
                estimator = "WLSMV", parameterization = "theta")
  }
  steps <- list(configural = NULL, thresholds = "thresholds", metric = c("thresholds", "loadings"), scalar = c("thresholds", "loadings", "intercepts"))
  expect_identical(as.character(rec$results$steps), names(steps))
  fits <- lapply(steps, fit_step)
  for (k in names(steps)) expect_identical(rec$results$fit[[k]]$chisq_scaled, as.numeric(lavaan::fitMeasures(fits[[k]], "chisq.scaled")), info = k)
  ref <- lavaan::lavTestLRT(fits$thresholds, fits$metric, method = "satorra.2000")
  expect_identical(rec$results$comparisons$chisq_diff[2], ref[2, "Chisq diff"])
  expect_identical(rec$results$comparisons$method[2], "satorra.2000")
  expect_match(rec$tables[[2]]$note_tr, "WLSMV için doğrulanmamıştır", fixed = TRUE)
  expect_true(rec$results$latent_means_available)
})

test_that("kategorikte üç kategorili maddelerde eşik adımı atlanır; ikili madde reddedilir", {
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  mod <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  d3 <- b10; d3$clean$data[, items10] <- lapply(d3$clean$data[, items10], function(v) ceiling(v / 2))
  d3$config$items$min <- 1; d3$config$items$max <- 3
  rec <- run_inv(list(model = mod, approach = "categorical"), d3)
  expect_false("thresholds" %in% rec$results$steps)
  expect_true("thresholds_skipped" %in% rec$results$notes)
  expect_match(rec$tables[[1]]$note_tr, "eşik adımı biçimselle eşdeğerdir", fixed = TRUE)
  d2 <- b10; d2$clean$data$A1 <- as.numeric(d2$clean$data$A1 > 3) + 1
  e <- tryCatch(run_inv(list(model = mod, approach = "categorical"), d2), error = function(e) e)
  expect_identical(e$code, "binary_items_not_supported")
})

test_that("skor testleri lavTestScore ile birebir; parametre adları okunur; sıralama χ²'ye göre", {
  rec <- analysis_invariance_scores(hs$clean$data, hs$config, list(model = m3, step = "scalar"), hs$hash)
  f <- ref_fit(c("loadings", "intercepts"))
  sc <- lavaan::lavTestScore(f, univariate = TRUE, cumulative = FALSE)$uni
  tests <- rec$results$tests
  expect_identical(sort(tests$x2, decreasing = TRUE), tests$x2)
  expect_identical(sort(tests$x2), sort(sc$X2))
  pt <- lavaan::parTable(f)
  top <- sc[which.max(sc$X2), ]
  r <- pt[pt$plabel == top$lhs, ]
  expect_identical(tests$free[1], if (r$op == "~1") paste0(r$lhs, "~1") else paste0(r$lhs, r$op, r$rhs))
  expect_identical(tests$groups[1], "Pasteur – Grant-White")
  e <- tryCatch(analysis_invariance_scores(hs$clean$data, hs$config, list(model = m3, step = "configural"), hs$hash), error = function(e) e)
  expect_identical(e$code, "invalid_setting")
})

test_that("grup değişkeni yoksa ya da grup küçükse açık hata", {
  bfi <- example_ds("bfi", items = paste0("A", 1:5))
  cfg <- bfi$config; cfg$group <- NULL
  e <- tryCatch(analysis_invariance(bfi$clean$data, cfg, list(model = list(factors = list(list(name = "A", items = paste0("A", 1:5))))), "h"), error = function(e) e)
  expect_identical(e$code, "no_group")
})
