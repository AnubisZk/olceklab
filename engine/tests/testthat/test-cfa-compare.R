# M6 — Model karşılaştırma. Beklenen değerler lavaan::lavTestLRT ve semTools::net doğrudan çağrılarak üretilir.

hs <- example_ds("holzinger")
hs_x <- hs$clean$data[, hs$config$items$name]
m3 <- list(factors = list(list(name = "visual", items = c("x1", "x2", "x3")), list(name = "textual", items = c("x4", "x5", "x6")),
                          list(name = "speed", items = c("x7", "x8", "x9"))))
m2 <- list(factors = list(list(name = "vt", items = paste0("x", 1:6)), list(name = "speed", items = c("x7", "x8", "x9"))))
m1 <- list(syntax = "g =~ x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9")
s3 <- "visual =~ x1 + x2 + x3\ntextual =~ x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
s2 <- "vt =~ x1 + x2 + x3 + x4 + x5 + x6\nspeed =~ x7 + x8 + x9"
s1 <- m1$syntax
models <- list(list(name = "Üç faktör", model = m3), list(name = "İki faktör", model = m2), list(name = "Tek faktör", model = m1))
run_cmp <- function(s, ds = hs) analysis_cfa_compare(ds$clean$data, ds$config, s, ds$hash)
find_test <- function(rec, a, b) Filter(function(t) t$restricted == a && t$reference == b, rec$results$tests)[[1]]

test_that("ML: bütün iç içe çiftler lavTestLRT ile birebir aynı; uyum tablosu modellerin fitMeasures değerleri", {
  rec <- run_cmp(list(models = models))
  f3 <- lavaan::cfa(s3, hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  f2 <- lavaan::cfa(s2, hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  f1 <- lavaan::cfa(s1, hs_x, estimator = "ML", likelihood = "normal", std.lv = FALSE)
  expect_length(rec$results$tests, 3L)
  for (pr in list(list("İki faktör", "Üç faktör", f3, f2), list("Tek faktör", "Üç faktör", f3, f1), list("Tek faktör", "İki faktör", f2, f1))) {
    ref <- lavaan::lavTestLRT(pr[[3]], pr[[4]])
    t <- find_test(rec, pr[[1]], pr[[2]])
    expect_identical(t$chisq_diff, ref[2, "Chisq diff"], info = paste(pr[[1]], pr[[2]]))
    expect_identical(t$df_diff, ref[2, "Df diff"])
    expect_identical(t$p, ref[2, "Pr(>Chisq)"])
    expect_identical(t$method, "standard")
  }
  t <- find_test(rec, "İki faktör", "Üç faktör")
  expect_identical(t$delta_cfi, as.numeric(lavaan::fitMeasures(f2, "cfi") - lavaan::fitMeasures(f3, "cfi")))
  expect_identical(rec$tables[[1]]$rows$chisq, unname(vapply(list(f3, f2, f1), function(f) as.numeric(lavaan::fitMeasures(f, "chisq")), 0)))
  expect_identical(rec$tables[[1]]$rows$aic, unname(vapply(list(f3, f2, f1), function(f) as.numeric(lavaan::fitMeasures(f, "aic")), 0)))
})

test_that("iç içelik semTools::net ile aynı belirlenir", {
  rec <- run_cmp(list(models = models))
  fit1 <- lavaan::cfa(s3, hs_x); fit2 <- lavaan::cfa(s2, hs_x); fit3 <- lavaan::cfa(s1, hs_x)
  ref <- semTools::net(fit1, fit2, fit3)@test
  expect_identical(rec$results$nesting$matrix, unname(ref))
})

test_that("Wishart: Δχ² = iki Wishart χ²'sinin farkı (§11.3 ile aynı kurulum)", {
  rec <- run_cmp(list(models = models[c(1, 3)], likelihood = "wishart"))
  f3 <- lavaan::cfa(s3, hs_x, likelihood = "wishart"); f1 <- lavaan::cfa(s1, hs_x, likelihood = "wishart")
  ref <- lavaan::anova(f3, f1)
  t <- find_test(rec, "Tek faktör", "Üç faktör")
  expect_identical(t$chisq_diff, ref[2, "Chisq diff"])
  expect_equal(t$chisq_diff, as.numeric(lavaan::fitMeasures(f1, "chisq") - lavaan::fitMeasures(f3, "chisq")), tolerance = 1e-10)
})

test_that("MLR: Satorra–Bentler (2001) yöntemi kayda yazılır ve lavTestLRT ile aynı (SPEC W-3)", {
  rec <- run_cmp(list(models = models[1:2], estimator = "MLR"))
  f3 <- lavaan::cfa(s3, hs_x, estimator = "MLR", std.lv = FALSE); f2 <- lavaan::cfa(s2, hs_x, estimator = "MLR", std.lv = FALSE)
  ref <- lavaan::lavTestLRT(f3, f2, method = "satorra.bentler.2001")
  t <- find_test(rec, "İki faktör", "Üç faktör")
  expect_identical(t$chisq_diff, ref[2, "Chisq diff"])
  expect_identical(t$method, "satorra.bentler.2001")
  expect_identical(rec$settings$lrt_method, "satorra.bentler.2001")
  # Elle çıkarılmış ölçeklenmiş χ² farkı test sonucundan farklıdır; motor bunu kullanmaz
  hand <- as.numeric(lavaan::fitMeasures(f2, "chisq.scaled") - lavaan::fitMeasures(f3, "chisq.scaled"))
  expect_false(isTRUE(all.equal(hand, t$chisq_diff)))
  expect_identical(rec$tables[[1]]$rows$cfi, unname(vapply(list(f3, f2), function(f) as.numeric(lavaan::fitMeasures(f, "cfi.scaled")), 0)))
  expect_identical(rec$tables[[1]]$rows$cfi_robust, unname(vapply(list(f3, f2), function(f) as.numeric(lavaan::fitMeasures(f, "cfi.robust")), 0)))
})

test_that("WLSMV: Satorra (2000) yöntemi ve lavTestLRT ile aynı; AIC/BIC sütunu yok", {
  items10 <- c(paste0("A", 1:5), paste0("C", 1:5))
  b10 <- example_ds("bfi", items = items10)
  x <- b10$clean$data[, b10$config$items$name]
  two <- list(factors = list(list(name = "A", items = paste0("A", 1:5)), list(name = "C", items = paste0("C", 1:5))))
  one <- list(factors = list(list(name = "G", items = items10)))
  rec <- run_cmp(list(models = list(list(name = "İki", model = two), list(name = "Tek", model = one)), estimator = "WLSMV"), b10)
  fa_ <- lavaan::cfa("A =~ A1 + A2 + A3 + A4 + A5\nC =~ C1 + C2 + C3 + C4 + C5", x, estimator = "WLSMV", std.lv = FALSE, ordered = b10$config$items$name)
  fb <- lavaan::cfa(paste("G =~", paste(items10, collapse = " + ")), x, estimator = "WLSMV", std.lv = FALSE, ordered = b10$config$items$name)
  ref <- lavaan::lavTestLRT(fa_, fb, method = "satorra.2000")
  t <- find_test(rec, "Tek", "İki")
  expect_identical(t$chisq_diff, ref[2, "Chisq diff"])
  expect_identical(t$method, "satorra.2000")
  expect_false("aic" %in% names(rec$tables[[1]]$rows))
})

test_that("iç içe olmayan modeller test edilmez; uyarı verilir", {
  cross <- list(syntax = "f1 =~ x1 + x2 + x3 + x4\nf2 =~ x5 + x6 + x7 + x8 + x9")
  rec <- run_cmp(list(models = list(list(name = "A", model = m3), list(name = "B", model = cross))))
  expect_length(rec$results$tests, 0L)
  expect_true("no_nested_pairs" %in% vapply(rec$warnings, `[[`, "", "code"))
  expect_length(rec$tables, 1L)
})

test_that("farklı gözlenen değişkenler, yinelenen adlar ve tek model reddedilir", {
  code <- function(s) tryCatch({ run_cmp(s); "ok" }, error = function(e) e$code)
  sub <- list(factors = list(list(name = "visual", items = c("x1", "x2", "x3")), list(name = "textual", items = c("x4", "x5", "x6"))))
  expect_identical(code(list(models = list(list(name = "A", model = m3), list(name = "B", model = sub)))), "compare_different_variables")
  expect_identical(code(list(models = list(list(name = "A", model = m3), list(name = "A", model = m2)))), "compare_duplicate_names")
  expect_identical(code(list(models = list(list(name = "A", model = m3)))), "compare_too_few_models")
  expect_identical(code(list(models = models, bootstrap = 200)), "invalid_setting")
})

test_that("SB2001 negatif çıkarsa SB2010 ile yeniden hesaplanır ve uyarı eklenir (denetim akışı)", {
  # Gerçek veride negatif SB2001 örneği bulunamadı (HS1939 ve bfi alt örneklemlerinde 500'den fazla deneme).
  # Bu test yalnızca dallanmayı sınar: ilk çağrının sonucu sahte olarak negatif verilir, ikinci çağrı gerçek lavaan'dır.
  # Testte görünen sahte değer hiçbir kayda ya da tabloya girmez; tabloya giren değer SB2010 sonucudur.
  real <- cfa_lrt
  assign("cfa_lrt", function(fit_less, fit_more, method) {
    if (method == "satorra.bentler.2001") return(list(chisq_diff = -1, df_diff = 2, p = 1, method = method, warnings = character()))
    real(fit_less, fit_more, method)
  }, envir = globalenv())
  withr::defer(assign("cfa_lrt", real, envir = globalenv()))
  rec <- run_cmp(list(models = models[1:2], estimator = "MLR"))
  t <- find_test(rec, "İki faktör", "Üç faktör")
  f3 <- lavaan::cfa(s3, hs_x, estimator = "MLR", std.lv = FALSE); f2 <- lavaan::cfa(s2, hs_x, estimator = "MLR", std.lv = FALSE)
  ref <- suppressWarnings(lavaan::lavTestLRT(f3, f2, method = "satorra.bentler.2010"))
  expect_identical(t$method, "satorra.bentler.2010")
  # lavaan'ın SB2010 uyarısı kullanıcıya iletilir
  expect_true(any(grepl("not positive definite", vapply(rec$warnings, `[[`, "", "message_tr"), fixed = TRUE)))
  expect_true(t$fallback)
  expect_identical(t$chisq_diff, ref[2, "Chisq diff"])
  expect_true("sb2001_negative" %in% vapply(rec$warnings, `[[`, "", "code"))
  expect_identical(rec$tables[[2]]$rows$chisq_diff, ref[2, "Chisq diff"])
})
