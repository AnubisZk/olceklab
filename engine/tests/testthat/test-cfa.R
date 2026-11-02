# M6 — DFA (tek model). Beklenen değerler lavaan::cfa doğrudan aynı ayarlarla çağrılarak üretilir
# (SPEC §11.2); lavaan belgesindeki HolzingerSwineford1939 değerleri raporlandıkları basamakta denetlenir.

hs <- example_ds("holzinger")
hs_x <- hs$clean$data[, hs$config$items$name]
m3_syntax <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
m3 <- list(factors = list(list(name = "visual", items = c("x1", "x2", "x3")), list(name = "textual", items = c("x4", "x5", "x6")),
                          list(name = "speed", items = c("x7", "x8", "x9"))))
fm_ref <- function(fit) {
  fm <- lavaan::fitMeasures(fit)
  out <- lapply(cfa_fit_names, function(n) if (n %in% names(fm)) unname(as.numeric(fm[[n]])) else NA_real_)
  stats::setNames(out, gsub(".", "_", cfa_fit_names, fixed = TRUE))
}
run_cfa <- function(s, ds = hs) analysis_cfa(ds$clean$data, ds$config, s, ds$hash)

test_that("HS1939 üç faktör (ML): lavaan belgesindeki uyum değerleri ve lavaan::cfa ile birebir aynı ölçütler", {
  rec <- run_cfa(list(model = m3))
  fit <- lavaan::cfa(m3_syntax, data = hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  expect_identical(rec$results$fit, fm_ref(fit))
  f <- rec$results$fit
  # lavaan eğitim belgesi (lavaan.ugent.be/tutorial/cfa): χ² = 85.306, sd = 24, CFI = .931, TLI = .896, RMSEA = .092 [.071, .114], SRMR = .065
  expect_true(at_reported_precision(f$chisq, 85.306, 3))
  expect_identical(f$df, 24)
  expect_true(at_reported_precision(f$cfi, 0.931, 3))
  expect_true(at_reported_precision(f$tli, 0.896, 3))
  expect_true(at_reported_precision(f$rmsea, 0.092, 3))
  expect_true(at_reported_precision(f$rmsea_ci_lower, 0.071, 3))
  expect_true(at_reported_precision(f$rmsea_ci_upper, 0.114, 3))
  expect_true(at_reported_precision(f$srmr, 0.065, 3))
  expect_identical(rec$settings$model$syntax, m3_syntax)
  expect_identical(rec$tables[[1]]$rows_fmt$tr$value[rec$tables[[1]]$rows$key == "chisq"], "85,306")
  expect_identical(rec$tables[[1]]$rows_fmt$en$value[rec$tables[[1]]$rows$key == "cfi"], ".931")
})

test_that("yükler, standart hatalar, β, R² ve faktör korelasyonları parameterEstimates ile aynı", {
  rec <- run_cfa(list(model = m3))
  fit <- lavaan::cfa(m3_syntax, data = hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  pe <- lavaan::parameterEstimates(fit, standardized = TRUE, rsquare = TRUE)
  ld <- pe[pe$op == "=~", ]
  got <- rec$results$loadings
  expect_identical(got$est, ld$est)
  expect_identical(got$std, ld$std.all)
  expect_identical(got$se[-c(1, 4, 7)], ld$se[-c(1, 4, 7)])
  expect_true(all(is.na(got$se[c(1, 4, 7)])))  # işaretleyici maddeler sabit
  r2 <- pe[pe$op == "r2", ]
  expect_identical(got$r2, r2$est[match(got$item, r2$lhs)])
  cr <- pe[pe$op == "~~" & pe$lhs == "visual" & pe$rhs == "textual", "std.all"]
  expect_identical(rec$results$factor_correlations$visual$textual, cr)
  # Faktör korelasyon tablosunun üst üçgeni boştur
  t3 <- rec$tables[[3]]
  expect_identical(t3$rows_fmt$tr$speed[1], "")
  expect_identical(t3$rows_fmt$tr$visual[2], fmt_num(cr, 3, "tr", TRUE))
})

test_that("std.lv = TRUE iken bütün yüklerin standart hatası vardır ve uyum değişmez", {
  a <- run_cfa(list(model = m3, std_lv = TRUE))
  b <- run_cfa(list(model = m3))
  expect_false(anyNA(a$results$loadings$se))
  expect_equal(a$results$fit$chisq, b$results$fit$chisq, tolerance = 1e-10)
  expect_equal(a$results$loadings$std, b$results$loadings$std, tolerance = 1e-5)  # iki parametreleştirmenin eniyileme yolu farklı
})

test_that("likelihood = 'wishart' (ML): lavaan ile aynı; χ² oranı N/(N − 1) (SPEC W-5)", {
  w <- run_cfa(list(model = m3, likelihood = "wishart"))
  n <- run_cfa(list(model = m3))
  fit <- lavaan::cfa(m3_syntax, data = hs_x, estimator = "ML", likelihood = "wishart", std.lv = FALSE)
  expect_identical(w$results$fit, fm_ref(fit))
  N <- nrow(hs_x)
  expect_equal(n$results$fit$chisq / w$results$fit$chisq, N / (N - 1), tolerance = 1e-8)
  expect_match(w$tables[[1]]$note_tr, "Wishart (N − 1; AMOS/LISREL uyumlu)", fixed = TRUE)
  expect_identical(w$settings$lavaan_args$likelihood, "wishart")
})

test_that("MLR: ölçeklenmiş ve dayanıklı indeksler iki ayrı, etiketli sütunda; değerler lavaan ile aynı (SPEC W-1)", {
  rec <- run_cfa(list(model = m3, estimator = "MLR"))
  fit <- lavaan::cfa(m3_syntax, data = hs_x, estimator = "MLR", std.lv = FALSE)
  ref <- fm_ref(fit)
  expect_identical(rec$results$fit, ref)
  t1 <- rec$tables[[1]]
  expect_identical(vapply(t1$columns, `[[`, "", "key"), c("label", "scaled", "robust"))
  expect_match(t1$columns[[2]]$label_tr, "Ölçeklenmiş (Yuan–Bentler)", fixed = TRUE)
  expect_match(t1$columns[[3]]$label_tr, "Dayanıklı", fixed = TRUE)
  expect_identical(t1$rows$scaled[t1$rows$key == "cfi"], ref$cfi_scaled)
  expect_identical(t1$rows$robust[t1$rows$key == "cfi"], ref$cfi_robust)
  expect_false(any(t1$rows$key == "chisq_df"))  # χ²/sd yalnızca ML'de (W-4)
})

test_that("WLSMV (bfi, 10 madde, sıralı): cfi.scaled ve cfi.robust lavaan ile aynı; AIC/BIC yok", {
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  x <- b10$clean$data[, b10$config$items$name]
  mod <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  rec <- run_cfa(list(model = mod, estimator = "WLSMV"), b10)
  fit <- lavaan::cfa("A =~ A1 + A2 + A3 + A4 + A5\nC =~ C1 + C2 + C3 + C4 + C5", data = x, estimator = "WLSMV",
                     std.lv = FALSE, ordered = b10$config$items$name)
  ref <- fm_ref(fit)
  expect_identical(rec$results$fit$cfi_scaled, ref$cfi_scaled)
  expect_identical(rec$results$fit$cfi_robust, ref$cfi_robust)
  expect_identical(rec$results$fit$rmsea_scaled, ref$rmsea_scaled)
  expect_identical(as.character(rec$settings$lavaan_args$ordered), b10$config$items$name)
  t1 <- rec$tables[[1]]
  expect_false(any(t1$rows$key %in% c("aic", "bic")))
  expect_match(t1$columns[[2]]$label_tr, "Mplus uyumlu", fixed = TRUE)
  expect_match(t1$columns[[3]]$label_tr, "Savalei, 2021", fixed = TRUE)
  expect_match(rec$tables[[2]]$note_tr, "y*", fixed = TRUE)
})

test_that("Bollen–Stine: p, B_etkin ve b lavaan ile aynı tohumla birebir; tutucu p R'de (SPEC BS-2, BS-3)", {
  rec <- run_cfa(list(model = m3, bootstrap = 100, seed = 7))
  old <- options(mc.cores = 1L); on.exit(options(old), add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection"); set.seed(7)
  fit <- suppressWarnings(lavaan::cfa(m3_syntax, data = hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE,
                                      test = "bollen.stine", bootstrap = 100L, iseed = 7L, parallel = "no"))
  bs <- lavaan::lavInspect(fit, "test")$bollen.stine
  got <- rec$results$bollen_stine
  expect_identical(got$pvalue, bs$pvalue)
  expect_identical(got$boot_length, as.integer(bs$boot.length))
  expect_identical(got$boot_larger, as.integer(bs$boot.larger))
  expect_identical(got$failed, 100L - as.integer(bs$boot.length))
  expect_identical(got$pvalue_conservative, (bs$boot.larger + 1) / (bs$boot.length + 1))
  expect_identical(rec$settings$lavaan_args$iseed, 7L)
  expect_identical(rec$settings$lavaan_args$parallel, "no")
  if (bs$boot.larger == 0) expect_identical(got$pvalue_fmt$tr, paste0("< ", fmt_num(ceiling(1e2 / bs$boot.length - 1e-9) / 1e2, 2, "tr", TRUE)))
  expect_identical(vapply(rec$tables, `[[`, "", "id")[length(rec$tables)], "T6")
  # Aynı tohum: aynı sonuç
  again <- run_cfa(list(model = m3, bootstrap = 100, seed = 7))
  expect_identical(again$results$bollen_stine$pvalue, got$pvalue)
})

test_that("Bollen–Stine yalnızca ML, sürekli ve eksiksiz veride seçilebilir (SPEC BS-1)", {
  code <- function(s, ds = hs) tryCatch({ run_cfa(s, ds); "ok" }, error = function(e) e$code)
  expect_identical(code(list(model = m3, estimator = "MLR", bootstrap = 200)), "bollen_stine_unavailable")
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  mod <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  expect_identical(code(list(model = mod, estimator = "WLSMV", bootstrap = 200), b10), "bollen_stine_unavailable")
  b_na <- example_ds("bfi", items = items10, rules = list(missing = FALSE))
  expect_true(anyNA(b_na$clean$data))
  expect_identical(code(list(model = mod, bootstrap = 200), b_na), "bollen_stine_unavailable")
  expect_identical(code(list(model = m3, bootstrap = 50)), "invalid_setting")
})

test_that("diğer ayar kısıtları: wishart yalnızca ML; WLSMV kategorili madde ister", {
  code <- function(s, ds = hs) tryCatch({ run_cfa(s, ds); "ok" }, error = function(e) e$code)
  expect_identical(code(list(model = m3, estimator = "MLR", likelihood = "wishart")), "wishart_only_ml")
  expect_identical(code(list(model = m3, estimator = "WLSMV")), "wlsmv_needs_categories")
  expect_identical(code(list(model = m3, estimator = "GLS")), "invalid_setting")
})

test_that("modifikasyon indeksleri lavaan::modindices ile aynı (en büyük 10)", {
  rec <- run_cfa(list(model = m3))
  fit <- lavaan::cfa(m3_syntax, data = hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  mi <- lavaan::modindices(fit, sort. = TRUE, maximum.number = 10L)
  got <- rec$results$modification_indices
  expect_identical(got$mi, mi$mi)
  expect_identical(paste(got$lhs, got$op, got$rhs), paste(mi$lhs, mi$op, mi$rhs))
  t5 <- Filter(function(t) t$id == "T5", rec$tables)[[1]]
  expect_match(t5$note_tr, "Kuramsal gerekçe olmadan", fixed = TRUE)
  none <- run_cfa(list(model = m3, mi_top = 0))
  expect_null(none$results$modification_indices)
})

test_that("hata kovaryansı modele eklenir ve tabloya girer", {
  rec <- run_cfa(list(model = c(m3, list(covariances = list(c("x7", "x8"))))))
  fit <- lavaan::cfa(paste0(m3_syntax, "\nx7 ~~ x8"), data = hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  pe <- lavaan::parameterEstimates(fit, standardized = TRUE)
  ref <- pe[pe$op == "~~" & pe$lhs == "x7" & pe$rhs == "x8", ]
  expect_identical(rec$results$error_covariances$std.all, ref$std.all)
  expect_true("T4" %in% vapply(rec$tables, `[[`, "", "id"))
  expect_identical(rec$results$fit$df, 23)
})

test_that("uygunsuz çözüm (negatif hata varyansı, |β| > 1) uyarılır; post.check kayda yazılır", {
  rec <- run_cfa(list(model = list(syntax = "v =~ x1 + x2 + x3 + x9\n t =~ x4 + x5 + x6\n s =~ x7 + x8\n s ~~ v")))
  codes <- vapply(rec$warnings, `[[`, "", "code")
  expect_true("heywood" %in% codes)
  expect_true("post_check_failed" %in% codes)
  expect_true("lavaan_warning" %in% codes)
  expect_false(rec$results$post_check)
  expect_true("factor_fewer_than_three" %in% codes)
})

test_that("tanımlanamayan model açık hatayla reddedilir", {
  e <- tryCatch(run_cfa(list(model = list(syntax = "f =~ x1 + x2"))), error = function(e) e)
  expect_identical(e$code, "model_not_identified")
  expect_identical(e$status, 422L)
})

test_that("yol şeması verisi R'de biçimlenmiş etiketler taşır", {
  rec <- run_cfa(list(model = m3))
  fig <- rec$figures[[1]]
  expect_identical(fig$type, "path")
  l1 <- fig$data$loadings[[2]]
  expect_identical(l1$label_tr, fmt_num(rec$results$loadings$std[2], 2, "tr", TRUE))
  expect_identical(l1$label_en, fmt_num(rec$results$loadings$std[2], 2, "en", TRUE))
  expect_length(fig$data$correlations, 3L)
  expect_identical(fig$data$correlations[[1]]$label_tr, fmt_num(rec$results$factor_correlations$visual$textual, 2, "tr", TRUE))
})
